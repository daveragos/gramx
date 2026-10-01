import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside the app, returning whether anything handled it.
///
/// Skips `canLaunchUrl`, which on Android 11+ returns false unless the intent
/// is declared in the manifest's `<queries>`.
Future<bool> openExternalUrl(Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
  } catch (e) {
    debugPrint('[Url] external launch failed for $uri: $e');
  }

  try {
    return await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (e) {
    debugPrint('[Url] platform launch failed for $uri: $e');
    return false;
  }
}

/// Adds an https scheme to a bare host such as `example.com`. URLs with a
/// scheme, including `mailto:` and `tel:`, are left alone.
Uri normalizeUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  final hasScheme =
      trimmed.contains('://') ||
      trimmed.startsWith('mailto:') ||
      trimmed.startsWith('tel:');
  return Uri.parse(hasScheme ? trimmed : 'https://$trimmed');
}
