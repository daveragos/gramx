import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:gramx/core/audio/opus_container.dart';

/// A fake Opus packet: the TOC byte, then filler of the given length.
Uint8List packet(int toc, int length, {int fill = 0x5A}) {
  final bytes = Uint8List(length)..fillRange(0, length, fill);
  bytes[0] = toc;
  return bytes;
}

/// SILK, 20 ms, one frame: 960 samples.
const silk20 = 1 << 3;

/// CELT, 2.5 ms, one frame: 120 samples.
const celt2_5 = 16 << 3;

void main() {
  group('samplesInPacket', () {
    test('reads the frame duration from the TOC config', () {
      expect(OpusStream.samplesInPacket(packet(silk20, 10)), 960);
      expect(OpusStream.samplesInPacket(packet(3 << 3, 10)), 2880);
      expect(OpusStream.samplesInPacket(packet(13 << 3, 10)), 960);
      expect(OpusStream.samplesInPacket(packet(celt2_5, 10)), 120);
      expect(OpusStream.samplesInPacket(packet(31 << 3, 10)), 960);
    });

    test('multiplies by the frame count', () {
      expect(OpusStream.samplesInPacket(packet(silk20 | 1, 10)), 1920);
      expect(OpusStream.samplesInPacket(packet(silk20 | 2, 10)), 1920);
      // Code 3 keeps the count in the low six bits of the second byte.
      final three = packet(silk20 | 3, 10)..[1] = 0x83;
      expect(OpusStream.samplesInPacket(three), 2880);
    });

    test('an empty packet decodes to nothing', () {
      expect(OpusStream.samplesInPacket(Uint8List(0)), 0);
    });
  });

  group('OGG', () {
    test('the header page matches one built by hand', () {
      const stream = OpusStream(channels: 1, preSkip: 312, packets: []);
      final ogg = OpusContainer.writeOgg(stream, serial: 1234);
      // Built and checksummed separately, with OGG's CRC-32.
      expect(ogg.sublist(0, 47), [
        79, 103, 103, 83, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 210, 4, 0, 0, 0, 0, //
        0, 0, 57, 89, 66, 88, 1, 19, 79, 112, 117, 115, 72, 101, 97, 100, //
        1, 1, 56, 1, 128, 187, 0, 0, 0, 0, 0,
      ]);
    });

    test('keeps every packet, including ones longer than a segment', () {
      final packets = [
        packet(silk20, 80),
        packet(silk20, 255, fill: 1),
        packet(silk20, 600, fill: 2),
        packet(silk20, 1, fill: 3),
      ];
      final stream = OpusStream(
        channels: 2,
        preSkip: 312,
        packets: packets,
        validSamples: 4 * 960 - 312 - 100,
      );

      final back = OpusContainer.readOgg(OpusContainer.writeOgg(stream));

      expect(back.channels, 2);
      expect(back.preSkip, 312);
      expect(back.validSamples, 4 * 960 - 312 - 100);
      expect(back.packets, packets);
    });

    test('spreads long recordings over pages', () {
      final packets = List.generate(500, (i) => packet(silk20, 40, fill: i));
      final ogg = OpusContainer.writeOgg(
        OpusStream(channels: 1, preSkip: 312, packets: packets),
      );

      final pages = 'OggS'.allMatches(String.fromCharCodes(ogg)).length;
      expect(pages, greaterThan(3));
      final back = OpusContainer.readOgg(ogg);
      expect(back.packets, packets);
      expect(back.validSamples, 500 * 960 - 312);
    });

    test('rejects what is not Ogg Opus', () {
      expect(
        () => OpusContainer.readOgg(Uint8List.fromList('hello'.codeUnits)),
        throwsFormatException,
      );
      expect(OpusContainer.isOgg(Uint8List.fromList('OggS'.codeUnits)), true);
    });
  });

  group('CAF', () {
    test('reads what Apple encodes', () {
      final caf = File('test/support/audio/tone_opus.caf').readAsBytesSync();
      final stream = OpusContainer.readCaf(caf);

      expect(stream.channels, 1);
      expect(stream.preSkip, 312);
      expect(stream.packets, hasLength(151));
      expect(stream.validSamples, 144000);
      expect(stream.decodedSamples, 151 * 960);
    });

    test('writes a fixed frame count when every packet has one', () {
      final packets = [packet(silk20, 90), packet(silk20, 300, fill: 7)];
      final caf = OpusContainer.writeCaf(
        OpusStream(channels: 1, preSkip: 312, packets: packets),
      );

      final back = OpusContainer.readCaf(caf);
      expect(back.packets, packets);
      expect(back.preSkip, 312);
      expect(back.validSamples, 2 * 960 - 312);
      // desc: frames per packet, after the 8-byte file header and 12-byte
      // chunk header.
      final desc = ByteData.sublistView(caf, 20, 52);
      expect(desc.getUint32(20), 960);
    });

    test('lists frame counts when packets differ', () {
      final packets = [packet(silk20, 90), packet(celt2_5, 20)];
      final caf = OpusContainer.writeCaf(
        OpusStream(channels: 1, preSkip: 0, packets: packets),
      );

      expect(ByteData.sublistView(caf, 20, 52).getUint32(20), 0);
      expect(OpusContainer.readCaf(caf).packets, packets);
    });

    test('rejects other formats', () {
      expect(
        () => OpusContainer.readCaf(Uint8List.fromList('RIFF0000'.codeUnits)),
        throwsFormatException,
      );
    });
  });

  test('Apple CAF survives a trip through OGG', () {
    final caf = File('test/support/audio/tone_opus.caf').readAsBytesSync();
    final original = OpusContainer.readCaf(caf);

    final ogg = OpusContainer.cafToOgg(caf, serial: 7);
    final back = OpusContainer.readCaf(OpusContainer.oggToCaf(ogg));

    expect(back.packets, original.packets);
    expect(back.preSkip, original.preSkip);
    expect(back.validSamples, original.validSamples);
  });
}
