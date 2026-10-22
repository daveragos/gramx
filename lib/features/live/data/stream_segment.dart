import 'dart:typed_data';

/// One piece of a live stream, as `getGroupCallStreamSegment` returns it.
///
/// Each piece starts with a short header: a little-endian signature, then
/// the container's name as a length-prefixed string ("mp4" for RTMP
/// streams), then fields Telegram doesn't document. The container itself
/// follows, so [payload] starts at its first box.
class StreamSegment {
  /// The header's first four bytes, read little-endian.
  static const int signature = 0xA12E810D;

  /// How far into a piece the container may start. The header seen so far
  /// is 32 bytes.
  static const int _maxHeader = 512;

  /// The container's name, such as "mp4".
  final String container;

  /// The container's bytes.
  final Uint8List payload;

  const StreamSegment._(this.container, this.payload);

  /// Reads [bytes], or returns null when they aren't a piece with an MP4
  /// container in it.
  static StreamSegment? parse(Uint8List bytes) {
    if (bytes.length < 16) return null;
    final view = ByteData.sublistView(bytes);
    if (view.getUint32(0, Endian.little) != signature) return null;

    final nameLength = bytes[4];
    if (5 + nameLength > bytes.length) return null;
    final container = String.fromCharCodes(bytes, 5, 5 + nameLength);
    if (container != 'mp4') return null;

    final limit = bytes.length - 8 < _maxHeader ? bytes.length - 8 : _maxHeader;
    for (var offset = 5 + nameLength; offset <= limit; offset++) {
      if (_isFtypAt(bytes, view, offset)) {
        return StreamSegment._(container, Uint8List.sublistView(bytes, offset));
      }
    }
    return null;
  }

  static bool _isFtypAt(Uint8List bytes, ByteData view, int offset) {
    if (bytes[offset + 4] != 0x66 || // f
        bytes[offset + 5] != 0x74 || // t
        bytes[offset + 6] != 0x79 || // y
        bytes[offset + 7] != 0x70) {
      // p
      return false;
    }
    final size = view.getUint32(offset);
    return size >= 16 && offset + size <= bytes.length;
  }
}
