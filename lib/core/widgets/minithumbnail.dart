import 'dart:collection';
import 'dart:convert';

import 'package:flutter/widgets.dart';

/// TDLib's minithumbnail, a tiny base64 JPEG shown while media loads, as one
/// image provider per string.
///
/// Decoding the string on every build made a new provider each time, so the
/// placeholder blinked as it decoded again on each download progress tick,
/// and every copy took a slot in the image cache.
abstract final class Minithumbnail {
  static const int _limit = 256;

  /// Most recently used last.
  static final LinkedHashMap<String, MemoryImage> _cache = LinkedHashMap();

  /// The provider for [base64], or null when there is none or it is corrupt.
  static ImageProvider? provider(String? base64) {
    if (base64 == null || base64.isEmpty) return null;

    final cached = _cache.remove(base64);
    if (cached != null) return _cache[base64] = cached;

    try {
      final image = MemoryImage(base64Decode(base64));
      _cache[base64] = image;
      if (_cache.length > _limit) _cache.remove(_cache.keys.first);
      return image;
    } on FormatException {
      return null;
    }
  }
}

/// Fades an image in once its first frame is ready, over whatever is behind
/// it, instead of showing nothing while it decodes. Use as an image's
/// `frameBuilder`.
Widget fadeInFrame(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded) return child;
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
    child: child,
  );
}
