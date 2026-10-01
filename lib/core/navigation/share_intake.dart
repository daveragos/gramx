import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Text shared into gramX from another app (Android only). `MainActivity`
/// parks it natively and Dart pulls it, since a share that launches the app
/// arrives before Dart has a handler.
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
