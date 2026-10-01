import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/compose/data/compose_media_picker.dart';
import 'package:gramx/features/compose/domain/compose_attachment.dart';

/// Full-screen recorder for a round video message.
///
/// The circle is only a mask: the rectangular file is sent whole, and the
/// `length` on `inputMessageVideoNote` tells Telegram how to centre-crop it.
class VideoNoteRecorderScreen extends StatefulWidget {
  const VideoNoteRecorderScreen({super.key});

  /// Telegram's maximum length for a round video message.
  static const Duration maxDuration = Duration(seconds: 60);

  /// Opens the recorder. Returns the recording, or null if the user backs out
  /// or recording fails.
  static Future<ComposeAttachment?> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<ComposeAttachment>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const VideoNoteRecorderScreen(),
      ),
    );
  }

  @override
  State<VideoNoteRecorderScreen> createState() =>
      _VideoNoteRecorderScreenState();
}

class _VideoNoteRecorderScreenState extends State<VideoNoteRecorderScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  bool _isRecording = false;
  bool _isFinishing = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Disposing without stopping discards any recording in progress.
    unawaited(_controller?.dispose());
    super.dispose();
  }

  /// The front camera if there is one, otherwise the first.
  int _preferredCamera(List<CameraDescription> cameras) {
    final front = cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    return front >= 0 ? front : 0;
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = AppStrings.videoNoteUnavailable);
        return;
      }
      if (!mounted) return;

      _cameras = cameras;
      _cameraIndex = _preferredCamera(cameras);
      await _attach(_cameras[_cameraIndex]);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        // A missing permission gets its own message since the user can fix it.
        _error = e.code.toLowerCase().contains('permission')
            ? AppStrings.videoNoteNoCamera
            : AppStrings.videoNoteUnavailable;
      });
    }
  }

  Future<void> _attach(CameraDescription camera) async {
    final previous = _controller;
    // Round notes display small, so a higher resolution only adds upload size.
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
    );

    await controller.initialize();
    await previous?.dispose();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _error = null;
    });
  }

  Future<void> _flip() async {
    if (_isRecording || _cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    try {
      await _attach(_cameras[_cameraIndex]);
    } on CameraException {
      if (mounted) setState(() => _error = AppStrings.videoNoteUnavailable);
    }
  }

  Future<void> _start() async {
    final controller = _controller;
    if (controller == null || _isRecording) return;

    try {
      await controller.startVideoRecording();
    } on CameraException {
      if (mounted) setState(() => _error = AppStrings.videoNoteUnavailable);
      return;
    }
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      _elapsed = Duration.zero;
    });

    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(milliseconds: 200));
      // Stops at Telegram's limit and keeps what was recorded.
      if (_elapsed >= VideoNoteRecorderScreen.maxDuration) _stop();
    });
  }

  Future<void> _stop() async {
    final controller = _controller;
    if (controller == null || !_isRecording || _isFinishing) return;

    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _isRecording = false;
      _isFinishing = true;
    });

    XFile? file;
    try {
      file = await controller.stopVideoRecording();
    } on CameraException {
      if (mounted) {
        setState(() {
          _isFinishing = false;
          _error = AppStrings.videoNoteUnavailable;
        });
      }
      return;
    }
    if (!mounted) return;

    // Duration and size come from the file; the ticker only counts wall time.
    final measured = await ComposeMediaPicker.describeVideo(file.path);
    if (!mounted) return;

    Navigator.of(context).pop(
      ComposeAttachment(
        path: measured.path,
        kind: ComposeMediaKind.videoNote,
        width: measured.width,
        height: measured.height,
        durationSeconds: measured.durationSeconds > 0
            ? measured.durationSeconds
            : _elapsed.inSeconds,
        sizeBytes: measured.sizeBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final remaining =
        VideoNoteRecorderScreen.maxDuration.inSeconds - _elapsed.inSeconds;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(AppStrings.videoNoteTitle),
        leading: IconButton(
          tooltip: AppStrings.videoNoteClose,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_cameras.length > 1 && !_isRecording)
            IconButton(
              tooltip: AppStrings.videoNoteFlip,
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: _flip,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppTypography.body(color: Colors.white),
                        ),
                      )
                    : controller == null || !controller.value.isInitialized
                    ? const CircularProgressIndicator(color: AppColors.accent)
                    : _RoundPreview(
                        controller: controller,
                        isRecording: _isRecording,
                      ),
              ),
            ),
            if (_error == null) ...[
              Text(
                _isRecording
                    ? AppStrings.videoNoteRemaining(
                        remaining < 0 ? 0 : remaining,
                      )
                    : AppStrings.videoNoteHint,
                style: AppTypography.body(color: Colors.white70),
              ),
              const SizedBox(height: AppSpacing.lg),
              _RecordButton(
                isRecording: _isRecording,
                isBusy: _isFinishing || controller == null,
                onPressed: _isRecording ? _stop : _start,
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ],
        ),
      ),
    );
  }
}

/// The viewfinder, masked to the circle the note will be cropped to.
class _RoundPreview extends StatelessWidget {
  final CameraController controller;
  final bool isRecording;

  const _RoundPreview({required this.controller, required this.isRecording});

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.of(context).size.width - AppSpacing.xxxl * 2;

    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          // Red while recording; the countdown below also shows the state.
          color: isRecording ? AppColors.error : Colors.white24,
          width: isRecording ? 3 : 1,
        ),
      ),
      child: ClipOval(
        // Centre-cropped the same way Telegram crops the sent note.
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? side,
            height: controller.value.previewSize?.width ?? side,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final bool isBusy;
  final VoidCallback onPressed;

  const _RecordButton({
    required this.isRecording,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isRecording
          ? AppStrings.videoNoteStop
          : AppStrings.videoNoteRecord,
      child: IconButton(
        iconSize: 64,
        tooltip: isRecording
            ? AppStrings.videoNoteStop
            : AppStrings.videoNoteRecord,
        onPressed: isBusy ? null : onPressed,
        icon: Icon(
          isRecording
              ? Icons.stop_circle_rounded
              : Icons.radio_button_checked_rounded,
          color: isBusy
              ? Colors.white24
              : (isRecording ? AppColors.error : Colors.white),
        ),
      ),
    );
  }
}
