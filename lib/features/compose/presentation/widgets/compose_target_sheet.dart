import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/channel_avatar.dart';
import 'package:gramx/features/compose/domain/compose_target.dart';
import 'package:gramx/features/compose/presentation/compose_providers.dart';

/// The destination picker behind the compose screen's pill.
class ComposeTargetSheet extends ConsumerStatefulWidget {
  /// What is currently selected, so the sheet can mark it.
  final ComposeTarget? selected;

  const ComposeTargetSheet({super.key, this.selected});

  /// Shows the sheet. Resolves to the chosen target, or null if dismissed.
  static Future<ComposeTarget?> show(
    BuildContext context, {
    ComposeTarget? selected,
  }) {
    return showModalBottomSheet<ComposeTarget>(
      context: context,
      // Above the shell's bottom bar; see mute_sheet.dart.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ComposeTargetSheet(selected: selected),
    );
  }

  @override
  ConsumerState<ComposeTargetSheet> createState() => _ComposeTargetSheetState();
}

class _ComposeTargetSheetState extends ConsumerState<ComposeTargetSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final needle = _query.trim().toLowerCase();
    final targets = ref
        .watch(composeTargetsProvider)
        .where(
          (t) =>
              needle.isEmpty ||
              composeTargetLabel(t).toLowerCase().contains(needle),
        )
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppStrings.composeTargetTitle,
                    style: AppTypography.heading(color: primary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: AppTypography.body(color: primary),
                  decoration: InputDecoration(
                    hintText: AppStrings.composeTargetSearchHint,
                    hintStyle: AppTypography.body(color: secondary),
                    prefixIcon: Icon(Icons.search, color: secondary, size: 20),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: targets.isEmpty
                    ? Center(
                        child: Text(
                          needle.isEmpty
                              ? AppStrings.composeTargetsEmpty
                              : AppStrings.composeTargetNoMatch,
                          style: AppTypography.body(color: secondary),
                        ),
                      )
                    : _TargetList(
                        targets: targets,
                        selected: widget.selected,
                        onPick: (t) => Navigator.of(context).pop(t),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The grouped list. Targets are already sorted by kind (see
/// [ComposeTargets.fromChats]), so a header goes wherever the kind changes.
class _TargetList extends StatelessWidget {
  final List<ComposeTarget> targets;
  final ComposeTarget? selected;
  final ValueChanged<ComposeTarget> onPick;

  const _TargetList({
    required this.targets,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return ListView.builder(
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        final startsSection =
            index == 0 || targets[index - 1].kind != target.kind;
        final isSelected = selected?.chatId == target.chatId;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (startsSection)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  composeTargetGroupLabel(target.kind),
                  style: AppTypography.actionCount(color: secondary),
                ),
              ),
            ListTile(
              leading: ComposeTargetAvatar(target: target),
              title: Text(
                composeTargetLabel(target),
                style: AppTypography.subheading(color: primary),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_rounded, color: AppColors.accent)
                  : null,
              selected: isSelected,
              onTap: () => onPick(target),
            ),
          ],
        );
      },
    );
  }
}

/// The avatar for one destination. Saved Messages gets an icon, since TDLib
/// gives it the account's own photo, which looks like a message from you.
class ComposeTargetAvatar extends StatelessWidget {
  final ComposeTarget target;
  final double radius;

  const ComposeTargetAvatar({
    super.key,
    required this.target,
    this.radius = AppSpacing.avatarSize / 2,
  });

  @override
  Widget build(BuildContext context) {
    if (target.kind == ComposeTargetKind.savedMessages) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.accent,
        child: Icon(Icons.bookmark_rounded, size: radius, color: Colors.white),
      );
    }

    return ChannelAvatar(
      title: target.title,
      avatarPath: target.avatarPath,
      avatarFileId: target.avatarFileId,
      radius: radius,
    );
  }
}

/// What a destination is called on screen. Saved Messages gets its own name,
/// since TDLib titles it with the account holder's name.
String composeTargetLabel(ComposeTarget target) =>
    target.kind == ComposeTargetKind.savedMessages
    ? AppStrings.composeSavedMessages
    : target.title;

String composeTargetGroupLabel(ComposeTargetKind kind) => switch (kind) {
  ComposeTargetKind.channel => AppStrings.composeGroupChannels,
  ComposeTargetKind.group => AppStrings.composeGroupGroups,
  ComposeTargetKind.savedMessages => AppStrings.composeGroupSaved,
  ComposeTargetKind.direct => AppStrings.composeGroupDirect,
};
