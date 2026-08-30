import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/diagnostics/error_log.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/time/time_utils.dart';

/// What the app knows about its own failures.
///
/// Plain, like the legal screens, and for the same reason: this is a thing to
/// be read and pasted, not a screen to be designed. The copy button is the
/// whole point — the log exists so somebody can be asked to send it.
///
/// Nothing here has left the device. There is no reporting endpoint, and the
/// privacy policy says as much; the records are redacted anyway, because a log
/// that is meant to be sent has to be safe to send.
class DiagnosticsScreen extends ConsumerWidget {
  static const route = '/diagnostics';

  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final log = ref.watch(errorLogProvider);
    final records = log.newestFirst;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.diagnosticsTitle,
          style: AppTypography.heading(color: primary),
        ),
        actions: [
          if (records.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: AppStrings.diagnosticsCopy,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text: ref.read(errorLogProvider.notifier).asText(),
                  ),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(AppStrings.diagnosticsCopied),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: AppStrings.diagnosticsClear,
              onPressed: () =>
                  ref.read(errorLogProvider.notifier).clear(),
            ),
          ],
        ],
      ),
      body: records.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 48,
                      color: secondary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppStrings.diagnosticsEmptyTitle,
                      style: AppTypography.subheading(color: primary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.diagnosticsEmptyBody,
                      style: AppTypography.body(color: secondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              itemCount: records.length + 1,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, thickness: 0.5, color: borderColor),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      AppStrings.diagnosticsBody,
                      style: AppTypography.actionCount(color: secondary),
                    ),
                  );
                }
                return _RecordTile(
                  record: records[index - 1],
                  primary: primary,
                  secondary: secondary,
                );
              },
            ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final ErrorRecord record;
  final Color primary;
  final Color secondary;

  const _RecordTile({
    required this.record,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final stack = record.stack;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppStrings.diagnosticsSource(record.source),
                style: AppTypography.username(color: AppColors.error),
              ),
              Text(
                AppStrings.inlineSeparator,
                style: AppTypography.username(color: secondary),
              ),
              Expanded(
                child: Text(
                  TimeUtils.relativeTime(record.at),
                  style: AppTypography.timestamp(color: secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          SelectableText(
            record.message,
            style: AppTypography.body(color: primary),
          ),
          if (stack != null) ...[
            const SizedBox(height: AppSpacing.xs),
            SelectableText(
              stack,
              style: AppTypography.timestamp(color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}
