import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/guest/data/guest_media_cache.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// The local file path for a picture, whichever of the two sources it came
/// from.
///
/// Signed in, a picture is a TDLib file id that resolves to a path once the
/// client has downloaded it. In guest mode it is an https URL from a preview
/// page, which [GuestMediaCache] fetches to disk. Both end as a path on disk,
/// so every widget below this can keep using `Image.file` and none of them has
/// to know which mode the reader is in.
///
/// Returns null while nothing has landed yet — the same "not ready" the
/// download provider already returns, and every caller already draws a
/// placeholder for it.
String? resolveMediaPath(
  WidgetRef ref, {
  int? fileId,
  String? rawPath,
}) {
  if (fileId != null && fileId != 0) {
    return ref.watch(fileDownloadProvider(fileId)).value;
  }

  if (rawPath == null || rawPath.isEmpty) return null;

  // A remote URL only ever comes from guest mode. Routed through the cache,
  // which refuses any host that is not Telegram's — the page it came from is
  // untrusted markup.
  if (rawPath.startsWith('https://') || rawPath.startsWith('http://')) {
    return ref.watch(guestMediaPathProvider(rawPath)).value;
  }

  return rawPath;
}

/// The `Ref` form, for providers rather than widgets.
String? resolveMediaPathFrom(
  Ref ref, {
  int? fileId,
  String? rawPath,
}) {
  if (fileId != null && fileId != 0) {
    return ref.watch(fileDownloadProvider(fileId)).value;
  }
  if (rawPath == null || rawPath.isEmpty) return null;
  if (rawPath.startsWith('https://') || rawPath.startsWith('http://')) {
    return ref.watch(guestMediaPathProvider(rawPath)).value;
  }
  return rawPath;
}
