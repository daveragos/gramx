import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Text shared into gramX from another app.
///
/// **Android only.** Receiving a share on iOS needs a Share Extension, which is
/// a second Xcode target with its own bundle id and app group — not something
/// the Dart side can declare. Asking here simply answers null there, which is
/// the same answer as "nothing was shared", so nothing has to know.
///
/// Pull rather than push, matching `MainActivity`: the text is parked natively
/// and asked for at startup and on every resume. A share that launches the app
/// arrives before Dart has a handler registered, so a push would need a parked
/// copy anyway — and then two paths would have to agree on which delivered it.
class ShareIntake {
  static const MethodChannel channel = MethodChannel(
    'dev.ragoose.gramx/share',
  );

  const ShareIntake();

  /// The text waiting, if any. Taking it clears it.
  Future<String?> take() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final text = await channel.invokeMethod<String>('takeSharedText');
      final trimmed = text?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } on MissingPluginException {
      // A build without the native half — a test, or a platform that has none.
      return null;
    } catch (e) {
      debugPrint('[Share] could not read the shared text: $e');
      return null;
    }
  }
}

final shareIntakeProvider = Provider<ShareIntake>((ref) => const ShareIntake());
