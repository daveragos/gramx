import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside the app, reporting whether anything took it.
///
/// Deliberately does **not** ask `canLaunchUrl` first. On Android 11+ that
/// answers false unless the target intent is declared in the manifest's
/// `<queries>`, and a caller that gates on it silently does nothing — which is
/// exactly why tapping a link preview card felt dead while the same link inside
/// the post text worked. Attempt the launch, and let the caller say so if it
/// fails.
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

/// Turns whatever a post carried into something launchable.
///
/// Bare hosts (`example.com`) get an https scheme; anything that already
/// declares one — including `tg:`, `mailto:` and `tel:` — is left alone.
Uri normalizeUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  final hasScheme =
      trimmed.contains('://') ||
      trimmed.startsWith('mailto:') ||
      trimmed.startsWith('tel:');
  return Uri.parse(hasScheme ? trimmed : 'https://$trimmed');
}
