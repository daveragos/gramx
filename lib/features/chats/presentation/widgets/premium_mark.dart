import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/presentation/widgets/custom_emoji_span.dart';

/// The check beside a Telegram Premium account's name. It is the same badge
/// as the verified check, so a name never shows two; see [PremiumMark.shows].
class PremiumCheck extends StatelessWidget {
  final double size;

  const PremiumCheck({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.verified,
      color: AppColors.verified,
      size: size,
      semanticLabel: AppStrings.a11yPremium,
    );
  }
}

/// A Premium account's mark in the conversation header and profile: the
/// user's emoji status if set (as Telegram shows it), otherwise the check.
/// Lists use [PremiumCheck] alone.
class PremiumMark extends StatelessWidget {
  final int? emojiStatusId;
  final double size;

  /// Whether the name already has the verified check.
  final bool isVerified;

  const PremiumMark({
    super.key,
    required this.emojiStatusId,
    required this.size,
    this.isVerified = false,
  });

  /// Whether to show a Premium mark. A verified account shows one only when
  /// it has an emoji status.
  static bool shows({
    required bool isPremium,
    required bool isVerified,
    int? emojiStatusId,
  }) => isPremium && (emojiStatusId != null || !isVerified);

  @override
  Widget build(BuildContext context) {
    final check = isVerified
        ? SizedBox.square(dimension: size)
        : PremiumCheck(size: size);
    final emojiId = emojiStatusId;
    if (emojiId == null) return check;

    return Semantics(
      label: AppStrings.a11yPremium,
      child: ExcludeSemantics(
        child: CustomEmojiGlyph(
          customEmojiId: emojiId,
          fallbackText: '',
          size: size,
          fallback: check,
        ),
      ),
    );
  }
}
