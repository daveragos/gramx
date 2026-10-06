import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/core/navigation/telegram_link.dart';

/// Text shared into gramX from another app on Android. `MainActivity` parks
/// it natively and Dart pulls it, since a share that launches the app arrives
/// before Dart has a handler. iOS shares arrive as links; see [ShareLinks].
class ShareIntake {
  static const MethodChannel channel = MethodChannel('dev.ragoose.gramx/share');

  const ShareIntake();

  /// The text waiting, if any. Taking it clears it.
  Future<String?> take() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final text = await channel.invokeMethod<String>('takeSharedText');
      final trimmed = text?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } on MissingPluginException {
      // No native side, as in tests.
      return null;
    } catch (e) {
      debugPrint('[Share] could not read the shared text: $e');
      return null;
    }
  }
}

final shareIntakeProvider = Provider<ShareIntake>((ref) => const ShareIntake());

/// The links the iOS share extension opens gramX with:
/// `gramx://share?text=…`.
abstract class ShareLinks {
  static const String scheme = 'gramx';

  /// The shared text in [uri], or null when it is not a share link.
  static String? sharedText(Uri uri) {
    if (uri.scheme.toLowerCase() != scheme || uri.host != 'share') return null;
    final text = uri.queryParameters['text']?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// The Telegram link that [text] is, when it is nothing else.
  ///
  /// iOS opens t.me links in the browser, never in another app, so sharing
  /// one to gramX is how a reader gets it here. Such a share opens the link
  /// instead of the composer.
  static Uri? telegramLinkIn(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) return null;

    var uri = Uri.tryParse(trimmed);
    // `t.me/name`, as typed in a note.
    if (uri != null && uri.scheme.isEmpty) {
      uri = Uri.tryParse('https://$trimmed');
    }
    if (uri == null || !TelegramLinks.couldBeTelegram(uri)) return null;
    return uri;
  }
}

/// Text from the iOS share extension, waiting for the shell to open the
/// composer with it.
class PendingSharedText extends Notifier<String?> {
  @override
  String? build() => null;

  void offer(String text) => state = text;

  /// Takes and clears the text, so it cannot open twice.
  String? take() {
    final text = state;
    state = null;
    return text;
  }
}

final pendingSharedTextProvider = NotifierProvider<PendingSharedText, String?>(
  PendingSharedText.new,
);
