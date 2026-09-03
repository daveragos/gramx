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

/// Recording a round video message.
///
/// Its own route rather than a control on the composer, and for one reason:
/// the viewfinder *is* the interface. A round note is framed — somebody points
/// a phone at their own face and the circle is what tells them whether they are
/// in it — and a preview small enough to sit above a keyboard is not a
/// viewfinder.
///
/// **The circle is a mask, not a crop.** The camera hands back a rectangular
/// file, and `inputMessageVideoNote` carries a `length` that Telegram and every
/// client use to centre-crop it into a circle. So what is drawn here is the
/// same crop the recipient will see, and the file that is sent is whole — which
/// is what every Telegram client does, and why a note recorded here plays
/// correctly in all of them.
class VideoNoteRecorderScreen extends StatefulWidget {
  const VideoNoteRecorderScreen({super.key});

  /// Telegram's ceiling for a round video message.
  static const Duration maxDuration = Duration(seconds: 60);

  /// Opens the recorder. Returns what was recorded, or null if the reader
  /// backed out — which includes every failure, each of which says so first.
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
    // Disposed without stopping: an in-flight recording on a route that is
    // going away is not one anybody meant to send, and `dispose` releases the
    // file with it.
    unawaited(_controller?.dispose());
    super.dispose();
  }

  /// Which camera to open first.
  ///
  /// The front one. A video message is a person talking to somebody, and a
  /// recorder that starts on the back camera opens on the ceiling.
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
        // The one failure worth naming separately: the reader can fix it, and
        // the fix is somewhere other than this screen.
        _error = e.code.toLowerCase().contains('permission')
            ? AppStrings.videoNoteNoCamera
            : AppStrings.videoNoteUnavailable;
      });
    }
  }

  Future<void> _attach(CameraDescription camera) async {
    final previous = _controller;
    // Medium, deliberately. A round note is drawn a couple of hundred pixels
    // across in every client, and recording 4K to be centre-cropped into a
    // circle costs the sender an upload nobody sees.
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
      setState(
        () => _elapsed += const Duration(milliseconds: 200),
      );
      // Stops itself at Telegram's ceiling and sends what it has, rather than
      // recording past a limit the send would then refuse.
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

    // Measured through the same probe a picked video goes through, so the
    // duration and dimensions on the message are read off the file rather than
    // taken from this screen's own clock — which counts wall time, not frames.
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
    final side =
        MediaQuery.of(context).size.width - AppSpacing.xxxl * 2;

    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          // The ring is the recording light. It is paired with the countdown
          // under it, so the state does not rest on a colour alone.
          color: isRecording ? AppColors.error : Colors.white24,
          width: isRecording ? 3 : 1,
        ),
      ),
      child: ClipOval(
        // The preview keeps its own aspect ratio and is centre-cropped by the
        // oval, which is exactly what Telegram does with `length` on the way
        // out — so the circle here is the circle they will see.
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
