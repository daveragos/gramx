import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/navigation/telegram_link.dart';
import 'package:gramx/features/guest/data/tme_page_parser.dart';
import 'package:gramx/features/guest/domain/guest_page.dart';

sealed class TmeFetchResult {
  const TmeFetchResult();
}

class TmeFetchSuccess extends TmeFetchResult {
  final GuestChannelPage page;
  final String? etag;
  final String? lastModified;

  const TmeFetchSuccess(this.page, {this.etag, this.lastModified});
}

/// The page has not changed since the validators that were sent.
class TmeFetchNotModified extends TmeFetchResult {
  const TmeFetchNotModified();
}

/// The name is not a public channel: private, deleted, or never existed.
class TmeFetchUnavailable extends TmeFetchResult {
  const TmeFetchUnavailable();
}

/// The page could not be fetched. [retryAt] is set while requests are paused.
class TmeFetchFailure extends TmeFetchResult {
  final String message;
  final DateTime? retryAt;

  const TmeFetchFailure(this.message, {this.retryAt});
}

/// Fetches public channel previews from `https://t.me/s/<username>`.
///
/// t.me limits requests per client, not per channel, so one pause applies to
/// every fetch: after a 429 or a server error nothing is sent until it ends.
class TmePreviewClient {
  TmePreviewClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  DateTime? _pausedUntil;

  static const _host = 't.me';
  static const _requestTimeout = Duration(seconds: 15);
  static const _defaultRetryAfter = Duration(seconds: 30);
  static const _maxRetryAfter = Duration(seconds: 120);
  static const _serverErrorPause = Duration(seconds: 10);
  static const _maxRedirects = 3;
  static const _redirectStatuses = {301, 302, 303, 307, 308};

  /// Chrome on Android, in the reduced form Chrome itself now sends. t.me
  /// serves a cut-down page to clients it does not take for a browser.
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36';

  /// Accept-Encoding is left to package:http, which only unpacks gzip on its
  /// own when it set the header itself.
  static final Map<String, String> _browserHeaders = {
    'User-Agent': _userAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': _acceptLanguage(),
  };

  /// When requests may resume, while a pause is in effect.
  DateTime? get rateLimitedUntil {
    final until = _pausedUntil;
    return until != null && until.isAfter(DateTime.now()) ? until : null;
  }

  /// The channel username in what a person pastes, or null if there is none.
  ///
  /// Takes a bare name, `@name`, and t.me, telegram.me or `tg://resolve`
  /// links to the channel, its preview or one of its posts.
  static String? parseUsername(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    final bare = text.startsWith('@') ? text.substring(1) : text;
    if (_isChannelUsername(bare)) return bare;

    // A link pasted without its scheme, such as `t.me/name`.
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(text);
    final uri = Uri.tryParse(hasScheme ? text : 'https://$text');
    if (uri == null) return null;

    final name = switch (TelegramLinks.parse(uri)) {
      TelegramChannelLink(:final username) => username,
      TelegramPostLink(:final username) => username,
      _ => null,
    };
    return name != null && _isChannelUsername(name) ? name : null;
  }

  /// Fetches the newest page of [username], or the page of posts older than
  /// post number [before].
  ///
  /// [etag] and [lastModified] are the validators of an earlier fetch of the
  /// same page; when the page is unchanged the result is
  /// [TmeFetchNotModified].
  Future<TmeFetchResult> fetchPage(
    String username, {
    int? before,
    String? etag,
    String? lastModified,
  }) async {
    if (!_isChannelUsername(username)) return const TmeFetchUnavailable();

    final unreadable = AppStrings.guestChannelUnreadable(username);
    final paused = rateLimitedUntil;
    if (paused != null) return TmeFetchFailure(unreadable, retryAt: paused);

    final headers = {
      ..._browserHeaders,
      'If-None-Match': ?etag,
      'If-Modified-Since': ?lastModified,
    };
    var uri = Uri.https(
      _host,
      '/s/$username',
      before == null ? null : {'before': '$before'},
    );

    try {
      for (var redirects = 0; ; redirects++) {
        final response = await _get(uri, headers);
        if (!_redirectStatuses.contains(response.statusCode)) {
          return _resultOf(response, username, unreadable);
        }
        // Anywhere but another preview page means there is no public preview:
        // t.me sends private and unknown names to its plain landing page.
        final next = _previewTarget(uri, response.headers['location']);
        if (next == null || redirects >= _maxRedirects) {
          return const TmeFetchUnavailable();
        }
        uri = next;
      }
    } on Exception catch (error) {
      // Timeouts, DNS, TLS and dropped connections all read the same way to
      // the person waiting.
      debugPrint('[Guest] t.me/s/$username failed: $error');
      return TmeFetchFailure(unreadable);
    }
  }

  /// Closes the underlying HTTP client.
  void close() => _http.close();

  Future<http.Response> _get(Uri uri, Map<String, String> headers) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest('GET', uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers.addAll(headers);
    try {
      return await _http
          .send(request)
          .then(http.Response.fromStream)
          .timeout(_requestTimeout);
    } finally {
      // Releases the connection after a timeout; harmless once the body is in.
      if (!abort.isCompleted) abort.complete();
    }
  }

  TmeFetchResult _resultOf(
    http.Response response,
    String username,
    String unreadable,
  ) {
    switch (response.statusCode) {
      case 200:
        // The page is UTF-8 whatever the headers say, and package:http would
        // fall back to Latin-1 if the charset were ever missing.
        final body = utf8.decode(response.bodyBytes, allowMalformed: true);
        final page = TmePageParser.parse(body, username);
        if (page == null) return const TmeFetchUnavailable();
        return TmeFetchSuccess(
          page,
          etag: response.headers['etag'],
          lastModified: response.headers['last-modified'],
        );
      case 304:
        return const TmeFetchNotModified();
      case 404 || 410:
        return const TmeFetchUnavailable();
      case 429:
        final wait = _retryAfter(response.headers['retry-after']);
        return TmeFetchFailure(unreadable, retryAt: _pause(wait));
      case >= 500:
        return TmeFetchFailure(unreadable, retryAt: _pause(_serverErrorPause));
      default:
        return TmeFetchFailure(unreadable);
    }
  }

  /// Holds every request until [wait] from now, never shortening a pause
  /// already running.
  DateTime _pause(Duration wait) {
    final until = DateTime.now().add(wait);
    final current = _pausedUntil;
    if (current == null || until.isAfter(current)) _pausedUntil = until;
    return _pausedUntil!;
  }

  /// Retry-After in seconds, defaulting to 30 and capped at 120 so a bad
  /// header cannot lock guest mode for long.
  static Duration _retryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    if (seconds == null || seconds < 0) return _defaultRetryAfter;
    final wait = Duration(seconds: seconds);
    return wait > _maxRetryAfter ? _maxRetryAfter : wait;
  }

  /// The redirect target when it is another t.me preview page.
  static Uri? _previewTarget(Uri from, String? location) {
    if (location == null || location.isEmpty) return null;
    final target = from.resolve(location);
    final segments = target.pathSegments;
    final isPreview =
        target.scheme == 'https' &&
        target.host == _host &&
        segments.length == 2 &&
        segments.first == 's';
    return isPreview ? target : null;
  }

  /// Telegram's rule for a public username: 4 to 32 letters, digits and
  /// underscores, starting with a letter (4-character names are sold on
  /// Fragment).
  static bool _isChannelUsername(String value) =>
      TelegramLinks.isUsername(value);

  /// The device language as an Accept-Language value, such as
  /// `am-ET,am;q=0.9,en;q=0.8`.
  static String _acceptLanguage() {
    String locale;
    try {
      locale = Platform.localeName;
    } on Exception {
      locale = '';
    }

    // POSIX names such as `en_US.UTF-8` or `sr_RS@latin` become BCP 47 tags.
    final tag = locale.split(RegExp('[.@]')).first.replaceAll('_', '-');
    final language = tag.split('-').first.toLowerCase();
    if (!RegExp(r'^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$').hasMatch(tag) ||
        language == 'c' ||
        language == 'posix') {
      return 'en';
    }

    return [
      tag,
      if (tag != language) '$language;q=0.9',
      if (language != 'en') 'en;q=0.8',
    ].join(',');
  }
}

final tmePreviewClientProvider = Provider<TmePreviewClient>((ref) {
  final client = TmePreviewClient();
  ref.onDispose(client.close);
  return client;
});
