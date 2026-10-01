import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_draft.dart';

/// Picks media from the gallery or a file from the system picker, and
/// measures it. `InputMessagePhoto` and `InputMessageVideo` need width and
/// height, or recipients see a blank placeholder until the download finishes.
class ComposeMediaPicker {
  final ImagePicker _picker;

  ComposeMediaPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// JPEG quality for the rescale to [ComposeLimits.photoLongestEdge], which
  /// keeps photos under [ComposeLimits.maxPhotoBytes].
  static const int _photoQuality = 90;

  /// How long to wait for a video's metadata. The platform player can hang on
  /// an unsupported codec, and the video is still sendable without it.
  static const Duration _videoProbeTimeout = Duration(seconds: 8);

  /// Picks one photo. Null if the user cancels.
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

  /// Picks one video. Null if the user cancels.
  Future<ComposeAttachment?> pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return null;
    return describeVideo(file.path);
  }

  /// Picks one file of any kind. Null if the user cancels. The system picker
  /// grants access to just this file, so no storage permission is needed.
  /// Size limits vary by account and are left to Telegram.
  Future<ComposeAttachment?> pickDocument() async {
    final result = await FilePicker.pickFiles(withData: false);
    final file = result?.files.singleOrNull;
    final path = file?.path;
    if (file == null || path == null) return null;

    return ComposeAttachment(
      path: path,
      kind: ComposeMediaKind.document,
      width: 0,
      height: 0,
      sizeBytes: file.size,
      fileName: file.name,
      // Only an extension; Telegram detects the real type from the content.
      mimeType: file.extension,
    );
  }

  /// Reads a photo's dimensions from its header without decoding it.
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
      // Unreadable formats still upload; only the size hint is lost.
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

  /// Reads a video's dimensions and duration using `video_player`. Also used
  /// by the round video recorder to measure its output.
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
