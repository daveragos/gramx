import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/features/guest/data/guest_media_cache.dart';
import 'package:gramx/infrastructure/telegram/file_download_provider.dart';

/// The local file path for a picture: a TDLib file id once downloaded, or a
/// guest-mode https URL fetched to disk by [GuestMediaCache]. Returns null
/// until the file is on disk.
String? resolveMediaPath(WidgetRef ref, {int? fileId, String? rawPath}) {
  if (fileId != null && fileId != 0) {
    return ref.watch(fileDownloadProvider(fileId)).value;
  }

  if (rawPath == null || rawPath.isEmpty) return null;

  // Remote URLs come only from guest mode. The cache refuses any host that
  // is not Telegram's, since the page they came from is untrusted.
  if (rawPath.startsWith('https://') || rawPath.startsWith('http://')) {
    return ref.watch(guestMediaPathProvider(rawPath)).value;
  }

  return rawPath;
}

/// The `Ref` form, for providers rather than widgets.
String? resolveMediaPathFrom(Ref ref, {int? fileId, String? rawPath}) {
  if (fileId != null && fileId != 0) {
    return ref.watch(fileDownloadProvider(fileId)).value;
  }
  if (rawPath == null || rawPath.isEmpty) return null;
  if (rawPath.startsWith('https://') || rawPath.startsWith('http://')) {
    return ref.watch(guestMediaPathProvider(rawPath)).value;
  }
  return rawPath;
}
