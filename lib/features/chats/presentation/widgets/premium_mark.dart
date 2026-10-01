import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/presentation/widgets/custom_emoji_span.dart';

/// The blue check beside a Telegram Premium account's name.
///
/// everywhere — the same badge, the same blue — rather than Telegram's star,
/// [PremiumMark.shows].
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

/// A Premium account's mark where the view is about that one person: the
/// conversation header and the profile.
///
/// Their own emoji status when they have set one — Telegram shows it in place
/// of the Premium badge, and it is the person's choice of how to be seen — and
/// the check otherwise, or while the emoji's artwork is still on its way. Lists
/// draw [PremiumCheck] alone.
class PremiumMark extends StatelessWidget {
  final int? emojiStatusId;
  final double size;

  /// Whether the name already carries the verified check, in which case a
  /// second check would say nothing more.
  final bool isVerified;

  const PremiumMark({
    super.key,
    required this.emojiStatusId,
    required this.size,
    this.isVerified = false,
  });

  /// Whether a name gets a Premium mark beside its verified check, if any.
  ///
  /// A verified Premium account shows its emoji status beside the check, as
  /// Telegram does; without one there is nothing to add to the check it
  /// already has.
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
