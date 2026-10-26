import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/trok/data/sse_decoder.dart';
import 'package:gramx/features/trok/data/trok_client.dart';
import 'package:gramx/features/trok/data/trok_credentials.dart';
import 'package:gramx/features/trok/data/trok_pictures.dart';
import 'package:gramx/features/trok/data/trok_post_files.dart';
import 'package:gramx/features/trok/data/trok_wire.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';

/// Where Trok's server answers. A build can point elsewhere with
/// `--dart-define=TROK_API=https://…/integrations/gramx/v1`.
const trokApiBase = String.fromEnvironment(
  'TROK_API',
  defaultValue: 'https://trok.iortr.online/integrations/gramx/v1',
);

/// Asks Trok's server over HTTPS. Each question is one request, and the
/// answer streams back on it as server-sent events.
class HttpTrokClient implements TrokClient {
  final TrokCredentials _credentials;
  final TrokPictures? _pictures;
  final TrokPostFiles? _postFiles;
  final http.Client _http;
  final Uri _base;

  /// The phone's language, for choosing what to translate into.
  final String Function() _deviceLanguage;

  /// The language the reader wants answers in: `en` or `am`.
  final String Function() _answerLanguage;

  /// Silence after which a connection is taken for dropped. Trok pings
  /// every 15 seconds while it works.
  final Duration silence;

  /// The wait before reconnecting to an answer, times the attempt.
  final Duration reconnectDelay;

  /// The posts each conversation's citations refer to, by Trok's id.
  final _refs = <String, TrokRefs>{};
  final _random = Random.secure();

  HttpTrokClient({
    required TrokCredentials credentials,
    TrokPictures? pictures,
    TrokPostFiles? postFiles,
    http.Client? client,
    String base = trokApiBase,
    String Function()? deviceLanguage,
    String Function()? answerLanguage,
    this.silence = const Duration(seconds: 60),
    this.reconnectDelay = const Duration(seconds: 1),
  }) : _credentials = credentials,
       _pictures = pictures,
       _postFiles = postFiles,
       _http = client ?? http.Client(),
       _base = Uri.parse(base.endsWith('/') ? base : '$base/'),
       _deviceLanguage =
           deviceLanguage ??
           (() => PlatformDispatcher.instance.locale.languageCode),
       _answerLanguage = answerLanguage ?? (() => 'en');

  /// How long a plain JSON call may take.
  static const _callTimeout = Duration(seconds: 20);

  /// How long a question waits for its post's pictures before going without.
  static const _picturesTimeout = Duration(seconds: 8);

  /// How long a question waits for its post's videos and voice notes to
  /// reach Trok before going without them.
  static const filesTimeout = Duration(seconds: 120);

  void close() => _http.close();

  @override
  Stream<TrokEvent> ask(TrokRequest request) {
    late final _Answer answer;
    final out = StreamController<TrokEvent>(
      onListen: () => unawaited(answer.run()),
      onCancel: () => answer.cancel(),
    );
    answer = _Answer(this, request, out);
    return out.stream;
  }

  @override
  Future<List<TrokConversation>> conversations() async {
    final json = await _json('GET', 'conversations', query: {'limit': '50'});
    return [
      for (final item
          in (json?['items'] as List? ?? const [])
              .whereType<Map<String, dynamic>>())
        if (item['id'] is String) TrokWire.summary(item),
    ];
  }

  @override
  Future<TrokConversation> conversation(String remoteId) async {
    final json = await _json('GET', 'conversations/$remoteId');
    if (json == null) throw TrokFailure('not_found', AppStrings.trokFailed);
    final refs = _refs[remoteId] ??= TrokRefs.rebuilt();
    return TrokWire.conversation(json, refs);
  }

  @override
  Future<void> deleteConversation(String remoteId) async {
    await _json('DELETE', 'conversations/$remoteId');
    _refs.remove(remoteId);
  }

  @override
  Future<TrokAllowance> allowance() async {
    final json = await _json('GET', 'me');
    if (json == null) throw TrokFailure('off', AppStrings.trokUnavailable);
    return TrokWire.allowance(json);
  }

  /// A plain JSON call, signing in again once if Trok asks.
  Future<Map<String, dynamic>?> _json(
    String method,
    String path, {
    Map<String, String>? query,
  }) async {
    for (var attempt = 0; ; attempt++) {
      final request = http.Request(
        method,
        _base.resolve(path).replace(queryParameters: query),
      )..headers.addAll(await _headers());
      final http.Response response;
      try {
        final streamed = await _http.send(request).timeout(_callTimeout);
        response = await http.Response.fromStream(
          streamed,
        ).timeout(_callTimeout);
      } on Exception catch (e) {
        debugPrint('[Trok] $method $path failed: $e');
        throw const TrokFailure('offline', AppStrings.trokOffline);
      }
      if (response.statusCode == HttpStatus.noContent) return null;
      if (response.statusCode == HttpStatus.ok) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        return body is Map<String, dynamic> ? body : null;
      }
      final failure = _failureOf(response.statusCode, response.bodyBytes);
      if (failure.code.startsWith('auth_') && attempt == 0) {
        _credentials.invalidate();
        continue;
      }
      throw failure;
    }
  }

  Future<Map<String, String>> _headers() async {
    final String initData;
    try {
      initData = await _credentials.initData();
    } on Exception catch (e) {
      // No Main Mini App to sign in with: Trok isn't on for this bot yet.
      debugPrint('[Trok] sign-in failed: $e');
      throw const TrokFailure('sign_in', AppStrings.trokUnavailable);
    }
    return {
      'Authorization': 'tma $initData',
      'X-Trok-Client':
          'gramx/${AppStrings.appVersion} (${Platform.operatingSystem})',
    };
  }

  /// The failure a non-200 response stands for.
  static TrokFailure _failureOf(int status, List<int> body) {
    Object? json;
    try {
      json = body.isEmpty ? null : jsonDecode(utf8.decode(body));
    } on FormatException {
      json = null;
    }
    final failure = TrokWire.failure(json);
    if (failure != null) return failure;
    // An empty 404 is how Trok says it's switched off.
    if (status == HttpStatus.notFound && body.isEmpty) {
      return const TrokFailure('off', AppStrings.trokUnavailable);
    }
    return TrokFailure('http_$status', AppStrings.trokFailed);
  }

  /// [post]'s pictures, or none if they can't be had in time: the question
  /// goes either way.
  Future<List<TrokPicture>> _picturesOf(Post? post) async {
    final pictures = _pictures;
    if (post == null || pictures == null) return const [];
    try {
      return await pictures.of(post).timeout(_picturesTimeout);
    } on Object catch (e) {
      debugPrint('[Trok] pictures of ${post.id} failed: $e');
      return const [];
    }
  }

  /// [post]'s videos and voice notes, sent to Trok ahead of the question.
  /// [sending] hears of each before it goes. Those that can't be sent before
  /// [abort] are left out: the question goes either way.
  Future<List<TrokSentFile>> _filesOf(
    Post? post, {
    required void Function(TrokFileType type, int? percent) sending,
    required Completer<void> abort,
  }) async {
    final postFiles = _postFiles;
    if (post == null || postFiles == null) return const [];
    final sent = <TrokSentFile>[];
    try {
      for (final file in await postFiles.of(post)) {
        if (abort.isCompleted) break;
        sending(file.type, null);
        final id = await _send(
          file,
          postFiles,
          abort,
          progress: (percent) => sending(file.type, percent),
        );
        if (id != null) sent.add((fileId: id, type: file.type));
      }
    } on Object catch (e) {
      debugPrint('[Trok] files of ${post.id} failed: $e');
    }
    return sent;
  }

  /// Trok's id for [file], uploading it unless Trok holds it already.
  Future<String?> _send(
    TrokPostFile file,
    TrokPostFiles postFiles,
    Completer<void> abort, {
    void Function(int percent)? progress,
  }) async {
    try {
      final local = await Future.any([
        postFiles.local(file),
        abort.future.then((_) => null),
      ]);
      if (local == null || abort.isCompleted) return null;
      final path = local.path;
      final hash = await _hashOf(path);
      final url = _base.resolve('files');
      final headers = {
        ...await _headers(),
        'Content-Type': file.mimeType,
        'X-Trok-File-Name': Uri.encodeComponent(file.name),
        'X-Trok-File-SHA256': hash,
      };

      // Asked with no body first: another reader of the post may have
      // sent the same file already.
      final check = http.AbortableRequest(
        'POST',
        url,
        abortTrigger: abort.future,
      )..headers.addAll(headers);
      final held = await http.Response.fromStream(
        await _http.send(check).timeout(_callTimeout),
      );
      if (held.statusCode == HttpStatus.ok) return _fileIdOf(held.bodyBytes);
      // An empty 404 is Trok switched off, not a file it lacks.
      if (held.statusCode != HttpStatus.notFound || held.bodyBytes.isEmpty) {
        debugPrint('[Trok] ${file.name} not checked: ${held.statusCode}');
        return null;
      }

      final size = await local.length();
      final upload =
          http.AbortableStreamedRequest('POST', url, abortTrigger: abort.future)
            ..headers.addAll(headers)
            ..contentLength = size;
      var sent = 0;
      var shown = 0;
      local.openRead().listen(
        (chunk) {
          upload.sink.add(chunk);
          sent += chunk.length;
          // Every tenth, so the step doesn't redraw for each chunk.
          final percent = size == 0 ? 100 : sent * 100 ~/ size;
          if (percent >= shown + 10 || percent == 100) {
            shown = percent;
            progress?.call(percent);
          }
        },
        onError: upload.sink.addError,
        onDone: upload.sink.close,
        cancelOnError: true,
      );
      final response = await http.Response.fromStream(await _http.send(upload));
      if (response.statusCode == HttpStatus.created ||
          response.statusCode == HttpStatus.ok) {
        return _fileIdOf(response.bodyBytes);
      }
      debugPrint('[Trok] ${file.name} not taken: ${response.statusCode}');
      return null;
    } on Object catch (e) {
      debugPrint('[Trok] ${file.name} not sent: $e');
      return null;
    }
  }

  static String? _fileIdOf(List<int> body) {
    try {
      final json = jsonDecode(utf8.decode(body));
      final id = json is Map<String, dynamic> ? json['file_id'] : null;
      return id is String && id.isNotEmpty ? id : null;
    } on FormatException {
      return null;
    }
  }

  /// [path]'s SHA-256, worked out off the main isolate. Kept apart so the
  /// isolate's closure holds nothing but the path.
  static Future<String> _hashOf(String path) =>
      Isolate.run(() => _sha256Of(path));

  static Future<String> _sha256Of(String path) async =>
      (await sha256.bind(File(path).openRead()).first).toString();

  /// A new question id: Trok answers each id once, so a retry repeats it.
  String _questionId() {
    final bytes = List.generate(16, (_) => _random.nextInt(256));
    return 'q_${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}

/// One answer being fetched, over as many connections as it takes.
class _Answer {
  final HttpTrokClient client;
  final TrokRequest request;
  final StreamController<TrokEvent> out;
  final String questionId;

  _Answer(this.client, this.request, this.out)
    : questionId = client._questionId();

  /// Dropped connections to rejoin before giving up.
  static const _reconnects = 2;

  /// A request body stays under this, with room for headers.
  static const _bodyLimit = 1000 * 1000 - 8 * 1024;

  bool _cancelled = false;
  Completer<void>? _abort;
  StreamSubscription<String>? _lines;

  /// Ended by a `done` or `error` event, or by the stream closing.
  Completer<void>? _ended;
  bool _finished = false;

  // What has been passed on. A rejoined answer is replayed from its start,
  // so it is only passed on past this.
  bool _started = false;
  int _stepsShown = 0;
  int _textShown = 0;

  // This connection's view of the answer.
  int _steps = 0;
  final _markdown = StringBuffer();

  late TrokRefs _refs;
  List<TrokPicture> _pictures = const [];
  List<TrokSentFile> _files = const [];

  /// Stops sending the post's files, when the reader stops the answer or
  /// they take too long.
  Completer<void>? _filesAbort;
  late String? _conversationId = request.conversationId;
  late String? _replaceAnswerId = request.replaceAnswerId;

  /// Whether one of the conversation's answers has come through. Trok
  /// keeps the feed and the post's pictures and files once it has read
  /// them; a conversation whose answers all failed may hold none of them.
  late final bool _answered = request.history.any(
    (turn) => turn is TrokAnswer && turn.state == TrokAnswerState.done,
  );

  /// Whether the feed and the post's pictures and files go with this
  /// question: on a new conversation, and on trying again after a failure.
  bool get _sendsContext => _conversationId == null || !_answered;

  /// The feed to send with a first question, without the post asked about.
  late List<Post> _feed = request.feed
      .where((p) => p.id != request.post?.id)
      .take(TrokWire.feedLimit)
      .toList();

  Future<void> run() async {
    final conversationId = _conversationId;
    _refs = conversationId == null
        ? TrokRefs()
        : client._refs.putIfAbsent(conversationId, TrokRefs.rebuilt);
    _pictures = await client._picturesOf(request.post);
    if (_cancelled) return;
    // Like pictures, files go only until Trok has answered about them.
    if (_sendsContext) {
      final abort = _filesAbort = Completer<void>();
      final timer = Timer(HttpTrokClient.filesTimeout, () {
        if (!abort.isCompleted) abort.complete();
      });
      _files = await client._filesOf(
        request.post,
        sending: _showSending,
        abort: abort,
      );
      timer.cancel();
      if (_cancelled) return;
    }
    var signedInAgain = false;
    var reconnects = 0;

    while (!_cancelled) {
      try {
        await _attempt();
        if (_cancelled) return;
        if (_finished) break;
        throw const _Dropped();
      } on TrokFailure catch (failure) {
        if (_cancelled) return;
        if (failure.code.startsWith('auth_') && !signedInAgain) {
          signedInAgain = true;
          client._credentials.invalidate();
          continue;
        }
        if (failure.code == 'not_found' && !_started) {
          // The answer to replace, or the conversation, is gone: ask anew.
          if (_replaceAnswerId != null) {
            _replaceAnswerId = null;
            continue;
          }
          if (_conversationId != null) {
            _conversationId = null;
            _refs = TrokRefs();
            continue;
          }
        }
        if (failure.code == 'too_large' && _feed.isNotEmpty && !_started) {
          _feed = _feed.take(_feed.length ~/ 2).toList();
          continue;
        }
        _fail(failure);
        return;
      } on Object catch (e) {
        if (_cancelled) return;
        if (reconnects++ < _reconnects) {
          debugPrint('[Trok] connection dropped, rejoining: $e');
          await Future<void>.delayed(client.reconnectDelay * reconnects);
          continue;
        }
        debugPrint('[Trok] answer failed: $e');
        _fail(const TrokFailure('offline', AppStrings.trokOffline));
        return;
      }
    }
    if (!_cancelled) await out.close();
  }

  /// Shows that a file is on its way before Trok has said anything, and
  /// how far its upload has got.
  void _showSending(TrokFileType type, int? percent) {
    if (out.isClosed) return;
    final step = type == TrokFileType.voice
        ? AppStrings.trokSendingVoice
        : AppStrings.trokSendingVideo;
    out.add(
      percent == null
          ? TrokStep(step)
          : TrokStep(
              AppStrings.trokSendingProgress(step, percent),
              replacesLast: true,
            ),
    );
  }

  /// Closing the connection tells Trok to stop writing.
  Future<void> cancel() async {
    _cancelled = true;
    final filesAbort = _filesAbort;
    if (filesAbort != null && !filesAbort.isCompleted) filesAbort.complete();
    _closeConnection();
    _end();
    await _lines?.cancel();
  }

  void _closeConnection() {
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
  }

  /// Ends the connection being read, with [error] if it failed.
  void _end([Object? error]) {
    final ended = _ended;
    if (ended == null || ended.isCompleted) return;
    error == null ? ended.complete() : ended.completeError(error);
  }

  Future<void> _attempt() async {
    _steps = 0;
    _markdown.clear();
    final abort = _abort = Completer<void>();
    try {
      final request =
          http.AbortableRequest(
              'POST',
              client._base.resolve('ask'),
              abortTrigger: abort.future,
            )
            ..headers.addAll(await client._headers())
            ..headers.addAll({
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
              'Idempotency-Key': questionId,
            })
            ..bodyBytes = _body();
      if (_cancelled) return;

      final response = await client._http.send(request).timeout(client.silence);
      if (response.statusCode != HttpStatus.ok) {
        final body = await response.stream.toBytes();
        throw HttpTrokClient._failureOf(response.statusCode, body);
      }

      final ended = _ended = Completer<void>();
      _lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(client.silence)
          .listen(
            _onLine(SseDecoder()),
            onError: _end,
            onDone: _end,
            cancelOnError: true,
          );
      await ended.future;
    } finally {
      await _lines?.cancel();
      _lines = null;
      _closeConnection();
    }
  }

  void Function(String) _onLine(SseDecoder decoder) => (line) {
    final event = decoder.add(line);
    if (event == null || _cancelled) return;
    try {
      _onEvent(event.event, jsonDecode(event.data));
    } on TrokFailure catch (failure) {
      _end(failure);
    } on Object catch (e) {
      debugPrint('[Trok] unreadable ${event.event} event: $e');
    }
  };

  void _onEvent(String type, Object? data) {
    final json = data is Map<String, dynamic>
        ? data
        : const <String, dynamic>{};
    switch (type) {
      case 'conversation':
        final conversationId = json['conversation_id'];
        final answerId = json['answer_id'];
        if (_started || conversationId is! String || answerId is! String) {
          return;
        }
        _started = true;
        _conversationId = conversationId;
        client._refs[conversationId] = _refs;
        out.add(
          TrokStarted(
            conversationId: conversationId,
            answerId: answerId,
            title: json['title'] as String? ?? '',
          ),
        );
      case 'step':
        final text = json['text'];
        if (text is! String) return;
        if (++_steps > _stepsShown) {
          _stepsShown = _steps;
          out.add(TrokStep(text));
        }
      case 'delta':
        final text = json['text'];
        if (text is! String) return;
        _markdown.write(text);
        // Replayed text shows again only once it passes what was shown.
        if (_markdown.length > _textShown) {
          _textShown = _markdown.length;
          out.add(TrokWire.text(_markdown.toString(), _refs, partial: true));
        }
      case 'sources':
        out.add(TrokSources(TrokWire.sources(json['items'], _refs)));
      case 'follow_ups':
        out.add(TrokFollowUps(TrokWire.followUps(json['items'])));
      case 'done':
        final text = json['text'];
        // The cleaned answer replaces what streamed.
        if (text is String) out.add(TrokWire.text(text, _refs));
        _finished = true;
        _end();
      case 'error':
        throw TrokWire.failure(json) ??
            const TrokFailure('unavailable', AppStrings.trokFailed);
    }
  }

  void _fail(TrokFailure failure) {
    if (out.isClosed) return;
    out.addError(failure);
    unawaited(out.close());
  }

  /// The request body, with fewer feed posts if all of them won't fit.
  List<int> _body() {
    final post = request.post;
    final sendsContext = _sendsContext;
    // Like the feed, pictures go only until Trok has answered, for it to
    // keep with the conversation. Sending them again would cost the reader
    // the data on every follow-up.
    final sentPost = post == null
        ? null
        : TrokWire.post(
            post,
            _refs.refFor(post),
            pictures: sendsContext ? _pictures : const [],
            files: sendsContext ? _files : const [],
          );
    var feed = sendsContext ? _feed : const <Post>[];
    while (true) {
      final body = utf8.encode(
        jsonEncode({
          'question_id': questionId,
          'conversation_id': _conversationId,
          'text': _cut(request.prompt, TrokWire.questionLimit),
          'action': TrokWire.action(request),
          'think': request.think,
          'language': client._answerLanguage(),
          'translate_to':
              request.action == TrokPostAction.translate && post != null
              ? TrokWire.translateTarget(
                  post,
                  client._deviceLanguage(),
                  answerLanguage: client._answerLanguage(),
                )
              : null,
          'replace_answer_id': _replaceAnswerId,
          'post': sentPost,
          'feed': [for (final p in feed) TrokWire.post(p, _refs.refFor(p))],
        }),
      );
      if (body.length <= _bodyLimit || feed.isEmpty) return body;
      // Read posts go first; they are at the end.
      feed = feed.take(feed.length * 3 ~/ 4).toList();
    }
  }

  static String _cut(String text, int limit) {
    if (text.length <= limit) return text;
    var end = limit;
    final unit = text.codeUnitAt(end - 1);
    if (unit >= 0xD800 && unit <= 0xDBFF) end--;
    return text.substring(0, end);
  }
}

/// The connection closed before the answer was done.
class _Dropped implements Exception {
  const _Dropped();
}
