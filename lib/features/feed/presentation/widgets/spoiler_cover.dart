import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';

/// Hides spoiler media behind a blur until the user taps to reveal it. Once
/// revealed, it stays revealed for the life of the card.
class SpoilerCover extends StatefulWidget {
  /// Screen reader description of what is underneath.
  final String label;
  final Widget child;

  /// Strong enough that nothing of the image shows through.
  static const double blurSigma = 18;

  const SpoilerCover({super.key, required this.label, required this.child});

  @override
  State<SpoilerCover> createState() => _SpoilerCoverState();
}

class _SpoilerCoverState extends State<SpoilerCover> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (_revealed) return widget.child;

    return Semantics(
      button: true,
      label: '${AppStrings.spoilerHidden}. ${widget.label}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => setState(() => _revealed = true),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            // Drawn over the loaded media so revealing is instant.
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: SpoilerCover.blurSigma,
                  sigmaY: SpoilerCover.blurSigma,
                ),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_off_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppStrings.spoilerTapToReveal,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
