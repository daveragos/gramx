import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:gramx/core/audio/opus_container.dart';

/// A path the platform player can open for the audio at [path].
///
/// Voice messages are Opus in OGG, and iOS plays Opus only from CAF, so on
/// iOS an OGG file is copied into a CAF beside the app's temporary files.
/// Anything else, and every file on Android, comes back as it is, as does a
/// file that fails to convert.
Future<String> playableAudioPath(String path) async {
  if (!Platform.isIOS) return path;
  try {
    final size = await File(path).length();
    final directory = p.join(
      (await getTemporaryDirectory()).path,
      'playable_audio',
    );
    // The size tells a finished download from a partial one at the same path.
    final target = File(
      p.join(directory, '${_fnv1a(path).toRadixString(16)}_$size.caf'),
    );
    if (await target.exists()) return target.path;

    final caf = await Isolate.run(() {
      final bytes = File(path).readAsBytesSync();
      return OpusContainer.isOgg(bytes) ? OpusContainer.oggToCaf(bytes) : null;
    });
    if (caf == null) return path;

    await Directory(directory).create(recursive: true);
    await target.writeAsBytes(caf, flush: true);
    return target.path;
  } catch (e) {
    debugPrint('[Audio] could not convert $path: $e');
    return path;
  }
}

/// A name for [path] that stays the same from one launch to the next, which
/// String.hashCode does not promise.
int _fnv1a(String text) {
  var hash = 0x811C9DC5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
