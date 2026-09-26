import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';

/// Hides media behind a blur until the reader taps to reveal it.
///
/// Telegram lets a poster mark media as a spoiler, and the app honoured that
/// for text but ignored it for images and video — so a spoiler was shown to
/// everyone regardless. Revealing has to be a deliberate tap: anything that
/// uncovers it by scrolling past defeats the point.
///
/// Once revealed it stays revealed for the life of the card. Re-hiding on
/// rebuild would flicker the cover back over media the reader already chose
/// to see.
class SpoilerCover extends StatefulWidget {
  /// Spoken description of what is underneath, for screen readers.
  final String label;
  final Widget child;

  /// Enough blur that nothing of the image survives it.
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
            // The blur sits over the real media rather than replacing it, so
            // revealing is instant — nothing has to load at that point.
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
