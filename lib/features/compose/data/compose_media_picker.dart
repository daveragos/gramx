import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_draft.dart';

/// Picks a photo or a video off the device and measures it.
///
/// Measuring is the part that matters. `InputMessagePhoto` and
/// `InputMessageVideo` both require width and height, and a post sent without
/// them lays out as a grey placeholder in every Telegram client until the file
/// finishes downloading — so the dimensions are read here, at the one moment
/// the app is allowed to take a beat, rather than guessed at send time.
///
/// Gallery only. Opening the camera would mean asking for the camera
/// permission, and this app has exactly one permission today.
class ComposeMediaPicker {
  final ImagePicker _picker;

  ComposeMediaPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// JPEG quality for the rescale to [ComposeLimits.photoLongestEdge].
  ///
  /// High enough to be invisible, low enough that a 2560px photo lands
  /// comfortably under [ComposeLimits.maxPhotoBytes] — which a modern phone
  /// camera clears without trying if nothing rescales it.
  static const int _photoQuality = 90;

  /// How long to wait for a video to report its own duration and size.
  ///
  /// Probing spins up a real platform player, and a codec the device dislikes
  /// can leave that hanging. The post is still sendable without the numbers, so
  /// this gives up rather than trapping the writer on a spinner.
  static const Duration _videoProbeTimeout = Duration(seconds: 8);

  /// Picks one photo. Null if the writer backed out of the gallery.
  Future<ComposeAttachment?> pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: ComposeLimits.photoLongestEdge.toDouble(),
      maxHeight: ComposeLimits.photoLongestEdge.toDouble(),
      imageQuality: _photoQuality,
    );
    if (file == null) return null;
    return describePhoto(file.path);
  }

  /// Picks one video. Null if the writer backed out of the gallery.
  Future<ComposeAttachment?> pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return null;
    return describeVideo(file.path);
  }

  /// Reads a photo's pixel dimensions off its header.
  ///
  /// [ui.ImageDescriptor.encoded] parses the header only — it does not decode
  /// the image — so this costs a file read and nothing else. Fully decoding a
  /// 2560px photo just to learn its width would cost 26 MB of RGBA.
  @visibleForTesting
  static Future<ComposeAttachment> describePhoto(String path) async {
    var width = 0;
    var height = 0;

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      width = descriptor.width;
      height = descriptor.height;
    } catch (e) {
      // A format Skia can't read still uploads fine; only the layout hint is
      // lost. See ComposeAttachment.hasUnknownSize.
      debugPrint('[ComposeMedia] Could not measure photo $path: $e');
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }

    return ComposeAttachment(
      path: path,
      kind: ComposeMediaKind.photo,
      width: width,
      height: height,
      sizeBytes: await _sizeOf(path),
    );
  }

  /// Reads a video's dimensions and duration.
  ///
  /// Uses `video_player`, which is already a dependency for playback, rather
  /// than adding a metadata package for three integers.
  @visibleForTesting
  static Future<ComposeAttachment> describeVideo(String path) async {
    var width = 0;
    var height = 0;
    var seconds = 0;

    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize().timeout(_videoProbeTimeout);
      final value = controller.value;
      width = value.size.width.round();
      height = value.size.height.round();
      seconds = value.duration.inSeconds;
    } catch (e) {
      debugPrint('[ComposeMedia] Could not measure video $path: $e');
    } finally {
      await controller.dispose();
    }

    return ComposeAttachment(
      path: path,
      kind: ComposeMediaKind.video,
      width: width,
      height: height,
      durationSeconds: seconds,
      sizeBytes: await _sizeOf(path),
    );
  }

  static Future<int> _sizeOf(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }
}
