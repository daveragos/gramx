import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/presentation/widgets/custom_emoji_span.dart';

/// Telegram Premium's star, beside a Premium account's name.
///
/// Drawn in Premium's own blue-to-pink rather than the app's accent, so it
/// cannot be read as the verified tick it sits next to: one says Telegram
/// checked who this is, the other that they pay for Telegram.
class PremiumStar extends StatelessWidget {
  final double size;

  const PremiumStar({super.key, required this.size});

  static const List<Color> _colors = [
    Color(0xFF6B93FF),
    Color(0xFF8878FF),
    Color(0xFFE46ACE),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.a11yPremium,
      child: ExcludeSemantics(
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _colors,
          ).createShader(bounds),
          child: Icon(Icons.star_rounded, size: size, color: Colors.white),
        ),
      ),
    );
  }
}

/// A Premium account's mark where the view is about that one person: the
/// conversation header and the profile.
///
/// Their own emoji status when they have set one — Telegram shows it in place
/// of the star, and it is the person's choice of how to be seen — and the
/// star otherwise, or while the emoji's artwork is still on its way. Lists
/// draw [PremiumStar] alone.
class PremiumMark extends StatelessWidget {
  final int? emojiStatusId;
  final double size;

  const PremiumMark({
    super.key,
    required this.emojiStatusId,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final star = PremiumStar(size: size);
    final emojiId = emojiStatusId;
    if (emojiId == null) return star;

    return Semantics(
      label: AppStrings.a11yPremium,
      child: ExcludeSemantics(
        child: CustomEmojiGlyph(
          customEmojiId: emojiId,
          fallbackText: '',
          size: size,
          fallback: star,
        ),
      ),
    );
  }
}
