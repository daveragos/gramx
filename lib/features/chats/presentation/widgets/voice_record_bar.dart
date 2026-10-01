import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/compose/domain/voice_waveform.dart';

/// Replaces the composer field while a voice message records, with cancel
/// and send buttons. The bars are the captured waveform that is sent with the
/// message.
class VoiceRecordBar extends StatelessWidget {
  /// How long the recording has been running.
  final Duration elapsed;

  /// Amplitudes so far, in Telegram's 0 to 31 range, oldest first.
  final List<int> waveform;

  final VoidCallback onCancel;
  final VoidCallback onSend;

  const VoiceRecordBar({
    super.key,
    required this.elapsed,
    required this.waveform,
    required this.onCancel,
    required this.onSend,
  });

  /// How many of the latest samples are drawn, so the display scrolls.
  static const int visibleBars = 48;

  String get _elapsedLabel {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final tail = waveform.length > visibleBars
        ? waveform.sublist(waveform.length - visibleBars)
        : waveform;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: AppStrings.voiceCancel,
            icon: Icon(Icons.delete_outline_rounded, color: secondary),
            onPressed: onCancel,
          ),
          // Recording dot, paired with the clock so it isn't colour alone.
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 44,
            child: Text(
              _elapsedLabel,
              style: AppTypography.body(color: theme.colorScheme.onSurface),
            ),
          ),
          Expanded(
            child: Semantics(
              label: AppStrings.voiceRecordingLabel(elapsed.inSeconds),
              child: SizedBox(
                height: 28,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    samples: tail,
                    color: AppColors.accent,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            tooltip: AppStrings.chatSend,
            style: IconButton.styleFrom(backgroundColor: AppColors.accent),
            icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}

/// Draws the amplitude bars, oldest at the left.
class _WaveformPainter extends CustomPainter {
  final List<int> samples;
  final Color color;

  const _WaveformPainter({required this.samples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    final slot = size.width / VoiceRecordBar.visibleBars;
    final barWidth = slot * 0.5;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var i = 0; i < samples.length; i++) {
      final fraction = samples[i] / VoiceWaveform.maxAmplitude;
      // A minimum height, so silence still draws a dot.
      final height = (size.height * fraction).clamp(2.0, size.height);
      final x = slot * i + slot / 2;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.samples.length != samples.length || old.color != color;
}
