import 'dart:math';
import 'dart:typed_data';

/// Opus audio as a list of packets, independent of the file it came in.
class OpusStream {
  final int channels;

  /// Samples at the start the decoder produces but nobody should hear.
  final int preSkip;

  /// The encoded packets, each one or more Opus frames.
  final List<Uint8List> packets;

  /// Samples to play after [preSkip]. Null when the file did not say, in
  /// which case every decoded sample after [preSkip] is played.
  final int? validSamples;

  const OpusStream({
    required this.channels,
    required this.preSkip,
    required this.packets,
    this.validSamples,
  });

  /// Samples the packets decode to at 48 kHz, before any trimming.
  int get decodedSamples =>
      packets.fold(0, (sum, packet) => sum + samplesInPacket(packet));

  /// How many samples a packet decodes to at 48 kHz, read from its TOC byte
  /// (RFC 6716, section 3.1).
  static int samplesInPacket(Uint8List packet) {
    if (packet.isEmpty) return 0;
    final toc = packet[0];
    final config = toc >> 3;
    final int frameSamples;
    if (config < 12) {
      frameSamples = const [480, 960, 1920, 2880][config & 3];
    } else if (config < 16) {
      frameSamples = const [480, 960][config & 1];
    } else {
      frameSamples = const [120, 240, 480, 960][config & 3];
    }
    final frames = switch (toc & 3) {
      0 => 1,
      1 || 2 => 2,
      _ => packet.length > 1 ? packet[1] & 0x3F : 0,
    };
    return frames * frameSamples;
  }
}

/// Moves Opus audio between OGG, the container Telegram uses for voice
/// messages, and CAF, the one Apple's audio frameworks read and write. Only
/// the container changes: packets are copied, never decoded or re-encoded.
class OpusContainer {
  OpusContainer._();

  /// Opus always decodes at 48 kHz, whatever rate it was recorded at.
  static const int sampleRate = 48000;

  /// Whether [bytes] start like an OGG file.
  static bool isOgg(Uint8List bytes) => _hasTag(bytes, 0, 'OggS');

  /// Whether [bytes] start like a CAF file.
  static bool isCaf(Uint8List bytes) => _hasTag(bytes, 0, 'caff');

  static Uint8List oggToCaf(Uint8List ogg) => writeCaf(readOgg(ogg));

  static Uint8List cafToOgg(Uint8List caf, {int? serial}) =>
      writeOgg(readCaf(caf), serial: serial);

  // OGG (RFC 3533), carrying Opus as RFC 7845 describes.

  static const int _granuleUnknown = -1;
  static const int _flagBeginning = 0x02;
  static const int _flagEnd = 0x04;

  /// Reads the first logical stream of an Ogg Opus file.
  static OpusStream readOgg(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final packets = <Uint8List>[];
    final pending = BytesBuilder(copy: false);
    int? serial;
    var lastGranule = _granuleUnknown;
    var offset = 0;

    while (offset + 27 <= bytes.length) {
      if (!_hasTag(bytes, offset, 'OggS')) {
        throw const FormatException('Not an OGG page');
      }
      final granule = data.getInt64(offset + 6, Endian.little);
      final pageSerial = data.getUint32(offset + 14, Endian.little);
      final segments = bytes[offset + 26];
      var body = offset + 27 + segments;
      if (body > bytes.length) break;

      final ours = (serial ??= pageSerial) == pageSerial;
      for (var i = 0; i < segments; i++) {
        final lacing = bytes[offset + 27 + i];
        if (body + lacing > bytes.length) break;
        if (ours) {
          pending.add(Uint8List.sublistView(bytes, body, body + lacing));
          // A lacing value under 255 ends the packet.
          if (lacing < 255) packets.add(pending.takeBytes());
        }
        body += lacing;
      }
      if (ours && granule != _granuleUnknown) lastGranule = granule;
      offset = body;
    }

    if (packets.length < 2 || !_hasTag(packets[0], 0, 'OpusHead')) {
      throw const FormatException('Not Ogg Opus');
    }
    final head = ByteData.sublistView(packets[0]);
    if (packets[0].length < 19) {
      throw const FormatException('Short OpusHead');
    }
    // Family 0 is mono or stereo; others need a channel mapping CAF lacks.
    if (head.getUint8(18) != 0) {
      throw const FormatException('Unsupported Opus channel mapping');
    }
    final preSkip = head.getUint16(10, Endian.little);

    // packets[1] is OpusTags, which carries nothing playback needs.
    final audio = packets.sublist(2);
    final stream = OpusStream(
      channels: head.getUint8(9),
      preSkip: preSkip,
      packets: audio,
    );
    if (lastGranule < preSkip) return stream;
    return OpusStream(
      channels: stream.channels,
      preSkip: preSkip,
      packets: audio,
      validSamples: min(lastGranule - preSkip, stream.decodedSamples - preSkip),
    );
  }

  /// Writes [stream] as Ogg Opus, a page per second or so of audio.
  static Uint8List writeOgg(OpusStream stream, {int? serial}) {
    final out = BytesBuilder(copy: false);
    final streamSerial = serial ?? Random().nextInt(1 << 32);
    var sequence = 0;

    void page(List<Uint8List> packets, int granule, int flags) {
      out.add(_oggPage(packets, granule, flags, streamSerial, sequence++));
    }

    final head = ByteData(19)
      ..setUint8(8, 1) // version
      ..setUint8(9, stream.channels)
      ..setUint16(10, stream.preSkip, Endian.little)
      ..setUint32(12, sampleRate, Endian.little)
      ..setInt16(16, 0, Endian.little) // output gain
      ..setUint8(18, 0); // channel mapping family
    final headBytes = head.buffer.asUint8List()
      ..setAll(0, 'OpusHead'.codeUnits);
    page([headBytes], 0, _flagBeginning);

    const vendor = 'gramX';
    final tags = ByteData(8 + 4 + vendor.length + 4)
      ..setUint32(8, vendor.length, Endian.little)
      ..setUint32(12 + vendor.length, 0, Endian.little); // no comments
    final tagBytes = tags.buffer.asUint8List()
      ..setAll(0, 'OpusTags'.codeUnits)
      ..setAll(12, vendor.codeUnits);
    page([tagBytes], 0, 0);

    final total = stream.validSamples == null
        ? null
        : stream.preSkip + stream.validSamples!;
    // A page's granule counts every sample decoded so far, pre-skip included.
    var granule = 0;
    var batch = <Uint8List>[];
    var batchSegments = 0;
    var batchSamples = 0;

    for (var i = 0; i < stream.packets.length; i++) {
      final packet = stream.packets[i];
      final segments = packet.length ~/ 255 + 1;
      if (batch.isNotEmpty &&
          (batchSegments + segments > 255 || batchSamples >= sampleRate)) {
        granule += batchSamples;
        page(batch, granule, 0);
        batch = [];
        batchSegments = 0;
        batchSamples = 0;
      }
      batch.add(packet);
      batchSegments += segments;
      batchSamples += OpusStream.samplesInPacket(packet);
    }

    granule += batchSamples;
    // The last page's granule may stop short of what it decodes to, which
    // trims the end (RFC 7845, section 4.4).
    if (total != null && total < granule) granule = total;
    page(batch, granule, _flagEnd);
    return out.takeBytes();
  }

  static Uint8List _oggPage(
    List<Uint8List> packets,
    int granule,
    int flags,
    int serial,
    int sequence,
  ) {
    final lacing = <int>[];
    var bodyLength = 0;
    for (final packet in packets) {
      var left = packet.length;
      while (left >= 255) {
        lacing.add(255);
        left -= 255;
      }
      lacing.add(left);
      bodyLength += packet.length;
    }

    final header = 27 + lacing.length;
    final page = Uint8List(header + bodyLength);
    final view = ByteData.sublistView(page)
      ..setUint8(4, 0) // version
      ..setUint8(5, flags)
      ..setInt64(6, granule, Endian.little)
      ..setUint32(14, serial, Endian.little)
      ..setUint32(18, sequence, Endian.little)
      ..setUint8(26, lacing.length);
    page.setAll(0, 'OggS'.codeUnits);
    page.setAll(27, lacing);
    var offset = header;
    for (final packet in packets) {
      page.setAll(offset, packet);
      offset += packet.length;
    }
    view.setUint32(22, _oggCrc(page), Endian.little);
    return page;
  }

  static final Uint32List _crcTable = () {
    final table = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var r = i << 24;
      for (var bit = 0; bit < 8; bit++) {
        r = (r & 0x80000000) != 0 ? (r << 1) ^ 0x04C11DB7 : r << 1;
      }
      table[i] = r & 0xFFFFFFFF;
    }
    return table;
  }();

  /// OGG's CRC-32: polynomial 0x04C11DB7, no reflection, no final xor.
  static int _oggCrc(Uint8List page) {
    var crc = 0;
    for (final byte in page) {
      crc = ((crc << 8) & 0xFFFFFFFF) ^ _crcTable[((crc >> 24) ^ byte) & 0xFF];
    }
    return crc;
  }

  // CAF, as Apple's Core Audio Format specification describes it. All
  // numbers are big-endian.

  /// Reads Opus from a CAF file such as AVAudioRecorder writes.
  static OpusStream readCaf(Uint8List bytes) {
    if (!isCaf(bytes)) throw const FormatException('Not a CAF file');
    final data = ByteData.sublistView(bytes);

    int? channels;
    var bytesPerPacket = 0;
    var framesPerPacket = 0;
    Uint8List? audio;
    ByteData? table;

    var offset = 8;
    while (offset + 12 <= bytes.length) {
      final type = String.fromCharCodes(bytes, offset, offset + 4);
      final size = data.getInt64(offset + 4);
      final start = offset + 12;
      // Only the data chunk may have an unknown size, meaning "to the end".
      final end = size < 0 ? bytes.length : min(start + size, bytes.length);

      switch (type) {
        case 'desc':
          if (!_hasTag(bytes, start + 8, 'opus')) {
            throw const FormatException('CAF does not hold Opus');
          }
          bytesPerPacket = data.getUint32(start + 16);
          framesPerPacket = data.getUint32(start + 20);
          channels = data.getUint32(start + 24);
        case 'pakt':
          table = ByteData.sublistView(bytes, start, end);
        case 'data':
          // Skips the edit count.
          audio = Uint8List.sublistView(bytes, start + 4, end);
      }
      offset = end;
    }

    if (channels == null || audio == null) {
      throw const FormatException('CAF is missing its format or audio');
    }

    final packets = <Uint8List>[];
    var preSkip = 0;
    int? validSamples;

    if (table != null) {
      final count = table.getInt64(0);
      validSamples = table.getInt64(8);
      preSkip = table.getInt32(16);
      var cursor = 24;
      int varint() {
        var value = 0;
        while (cursor < table!.lengthInBytes) {
          final byte = table.getUint8(cursor++);
          value = (value << 7) | (byte & 0x7F);
          if (byte & 0x80 == 0) break;
        }
        return value;
      }

      var position = 0;
      for (var i = 0; i < count; i++) {
        final size = bytesPerPacket != 0 ? bytesPerPacket : varint();
        if (framesPerPacket == 0) varint();
        if (position + size > audio.length) break;
        packets.add(Uint8List.sublistView(audio, position, position + size));
        position += size;
      }
    } else if (bytesPerPacket != 0) {
      for (var p = 0; p + bytesPerPacket <= audio.length; p += bytesPerPacket) {
        packets.add(Uint8List.sublistView(audio, p, p + bytesPerPacket));
      }
    } else {
      throw const FormatException('CAF has no packet table');
    }

    return OpusStream(
      channels: channels,
      preSkip: preSkip,
      packets: packets,
      validSamples: validSamples,
    );
  }

  /// Writes [stream] as CAF, laid out the way Apple's own encoder does.
  static Uint8List writeCaf(OpusStream stream) {
    final sizes = [
      for (final p in stream.packets) OpusStream.samplesInPacket(p),
    ];
    final decoded = sizes.fold(0, (a, b) => a + b);
    // A fixed frame count lets the table hold sizes alone.
    final fixed = sizes.isNotEmpty && sizes.every((s) => s == sizes.first)
        ? sizes.first
        : 0;
    final valid = stream.validSamples ?? max(0, decoded - stream.preSkip);

    final out = BytesBuilder(copy: false);
    out.add(const [0x63, 0x61, 0x66, 0x66, 0, 1, 0, 0]); // 'caff', v1

    void chunk(String type, Uint8List body) {
      final header = ByteData(12)..setInt64(4, body.length);
      out.add(header.buffer.asUint8List()..setAll(0, type.codeUnits));
      out.add(body);
    }

    final desc = ByteData(32)
      ..setFloat64(0, sampleRate.toDouble())
      ..setUint32(12, 0) // format flags
      ..setUint32(16, 0) // bytes per packet: variable
      ..setUint32(20, fixed)
      ..setUint32(24, stream.channels)
      ..setUint32(28, 0); // bits per channel
    chunk('desc', desc.buffer.asUint8List()..setAll(8, 'opus'.codeUnits));

    final entries = BytesBuilder(copy: false);
    for (var i = 0; i < stream.packets.length; i++) {
      entries.add(_varint(stream.packets[i].length));
      if (fixed == 0) entries.add(_varint(sizes[i]));
    }
    final pakt = ByteData(24)
      ..setInt64(0, stream.packets.length)
      ..setInt64(8, valid)
      ..setInt32(16, stream.preSkip)
      ..setInt32(20, max(0, decoded - stream.preSkip - valid));
    chunk(
      'pakt',
      (BytesBuilder(copy: false)
            ..add(pakt.buffer.asUint8List())
            ..add(entries.takeBytes()))
          .takeBytes(),
    );

    final audio = BytesBuilder(copy: false)..add(const [0, 0, 0, 0]);
    for (final packet in stream.packets) {
      audio.add(packet);
    }
    chunk('data', audio.takeBytes());
    return out.takeBytes();
  }

  /// CAF's variable-length integer: seven bits a byte, most significant
  /// first, the high bit set on every byte but the last.
  static Uint8List _varint(int value) {
    final bytes = <int>[value & 0x7F];
    value >>= 7;
    while (value > 0) {
      bytes.insert(0, (value & 0x7F) | 0x80);
      value >>= 7;
    }
    return Uint8List.fromList(bytes);
  }

  static bool _hasTag(Uint8List bytes, int offset, String tag) {
    if (offset + tag.length > bytes.length) return false;
    for (var i = 0; i < tag.length; i++) {
      if (bytes[offset + i] != tag.codeUnitAt(i)) return false;
    }
    return true;
  }
}
