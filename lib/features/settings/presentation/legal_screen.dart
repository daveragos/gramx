import 'package:flutter/material.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/l10n/legal_text.dart';

/// Renders one of the legal documents.
///
/// Plain and scrollable on purpose: this is a thing to be read, not a screen
/// to be designed. It is also why both documents live in the app rather than
/// behind a link — someone with no signal, or no patience for a browser, can
/// still read what they are agreeing to before they agree to it.
class LegalScreen extends StatelessWidget {
  final String documentId;

  const LegalScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final document = LegalTexts.byId(documentId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          document?.title ?? AppStrings.legalNotFoundTitle,
          style: AppTypography.heading(color: primary),
        ),
      ),
      body: document == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  AppStrings.legalNotFoundBody,
                  style: AppTypography.body(color: secondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  document.summary,
                  style: AppTypography.body(color: primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.legalLastUpdated(document.lastUpdated),
                  style: AppTypography.actionCount(color: secondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final section in document.sections) ...[
                  Text(
                    section.heading,
                    style: AppTypography.subheading(color: primary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final paragraph in section.paragraphs) ...[
                    Text(
                      paragraph,
                      style: AppTypography.body(
                        color: secondary,
                      ).copyWith(height: 1.45),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
    );
  }
}
