import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/search/domain/search_filters.dart';

/// The filters the next search uses.
class SearchFiltersNotifier extends Notifier<SearchFilters> {
  @override
  SearchFilters build() => const SearchFilters();

  void set(SearchFilters filters) => state = filters;
}

final searchFiltersProvider =
    NotifierProvider<SearchFiltersNotifier, SearchFilters>(
      SearchFiltersNotifier.new,
    );

/// X's search filters, as a sheet. Changes are a draft until Search is
/// pressed; closing the sheet drops them.
Future<void> showSearchFilters(BuildContext context) {
  HapticFeedback.lightImpact();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const SearchFiltersSheet(),
  );
}

/// Which list of options the sheet is showing, if any.
enum _Page { main, from, date, type }

class SearchFiltersSheet extends ConsumerStatefulWidget {
  const SearchFiltersSheet({super.key});

  @override
  ConsumerState<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends ConsumerState<SearchFiltersSheet> {
  late SearchFilters _draft = ref.read(searchFiltersProvider);
  _Page _page = _Page.main;

  void _apply() {
    ref.read(searchFiltersProvider.notifier).set(_draft);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Material(
          color: surface,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(_page),
                child: _page == _Page.main ? _main() : _options(_page),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _main() {
    final folders = ref.watch(foldersProvider).value ?? const [];
    final folderTitle = [
      for (final folder in folders)
        if (folder.id == _draft.folderId) folder.title,
    ].firstOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: AppStrings.searchFiltersTitle,
          leading: null,
          trailing: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        _ValueRow(
          label: AppStrings.searchFilterFrom,
          value: folderTitle ?? AppStrings.searchFromAllChannels,
          onTap: () => setState(() => _page = _Page.from),
        ),
        _ValueRow(
          label: AppStrings.searchFilterDate,
          value: _dateLabel(_draft.date),
          onTap: () => setState(() => _page = _Page.date),
        ),
        _ValueRow(
          label: AppStrings.searchFilterType,
          value: _typeLabel(_draft.type),
          onTap: () => setState(() => _page = _Page.type),
        ),
        _SwitchRow(
          label: AppStrings.searchFilterExcludeReplies,
          value: _draft.excludeReplies,
          onChanged: (v) =>
              setState(() => _draft = _draft.copyWith(excludeReplies: v)),
        ),
        _SwitchRow(
          label: AppStrings.searchFilterExcludeReposts,
          value: _draft.excludeReposts,
          onChanged: (v) =>
              setState(() => _draft = _draft.copyWith(excludeReposts: v)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Row(
            children: [
              Expanded(
                child: _Pill(
                  label: AppStrings.searchFiltersReset,
                  filled: false,
                  onPressed: () =>
                      setState(() => _draft = const SearchFilters()),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Pill(
                  label: AppStrings.searchFiltersApply,
                  filled: true,
                  onPressed: _apply,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The options for one row, each checked when chosen. Choosing returns to
  /// the main page.
  Widget _options(_Page page) {
    final folders = ref.watch(foldersProvider).value ?? const [];

    final (
      String title,
      List<(String, bool, VoidCallback)> options,
    ) = switch (page) {
      _Page.from => (
        AppStrings.searchFilterFrom,
        [
          (
            AppStrings.searchFromAllChannels,
            _draft.folderId == null,
            () => _draft = _draft.withFolder(null),
          ),
          for (final folder in folders)
            (
              folder.title,
              _draft.folderId == folder.id,
              () => _draft = _draft.withFolder(folder.id),
            ),
        ],
      ),
      _Page.date => (
        AppStrings.searchFilterDate,
        [
          for (final range in SearchDateRange.values)
            (
              _dateLabel(range),
              _draft.date == range,
              () => _draft = _draft.copyWith(date: range),
            ),
        ],
      ),
      _Page.type || _Page.main => (
        AppStrings.searchFilterType,
        [
          for (final type in SearchMediaType.values)
            (
              _typeLabel(type),
              _draft.type == type,
              () => _draft = _draft.copyWith(type: type),
            ),
        ],
      ),
    };

    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: title,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => setState(() => _page = _Page.main),
            icon: const Icon(Icons.arrow_back),
          ),
          trailing: null,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              for (final (label, selected, choose) in options)
                _OptionRow(
                  label: label,
                  selected: selected,
                  onTap: () => setState(() {
                    choose();
                    _page = _Page.main;
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _dateLabel(SearchDateRange range) => switch (range) {
    SearchDateRange.allTime => AppStrings.searchDateAllTime,
    SearchDateRange.day => AppStrings.searchDateDay,
    SearchDateRange.week => AppStrings.searchDateWeek,
    SearchDateRange.month => AppStrings.searchDateMonth,
    SearchDateRange.year => AppStrings.searchDateYear,
  };

  static String _typeLabel(SearchMediaType type) => switch (type) {
    SearchMediaType.any => AppStrings.searchTypeAny,
    SearchMediaType.photos => AppStrings.searchTypePhotos,
    SearchMediaType.videos => AppStrings.searchTypeVideos,
    SearchMediaType.links => AppStrings.searchTypeLinks,
    SearchMediaType.files => AppStrings.searchTypeFiles,
    SearchMediaType.voice => AppStrings.searchTypeVoice,
    SearchMediaType.music => AppStrings.searchTypeMusic,
  };
}

/// The sheet's title row, over a hairline.
class _Header extends StatelessWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;

  const _Header({
    required this.title,
    required this.leading,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                if (leading != null) leading! else const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.heading(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Divider(
            height: AppSpacing.md,
            thickness: 0.5,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ],
      ),
    );
  }
}

/// A filter and its current choice, which opens the choices.
class _ValueRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ValueRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: AppTypography.bodyLarge(
                color: theme.colorScheme.onSurface,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyLarge(color: secondary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right_rounded, color: secondary),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyLarge(
                    color: theme.colorScheme.onSurface,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reset and Search: a quiet pill and a filled one, as on X.
class _Pill extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onPressed;

  const _Pill({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final background = filled
        ? onSurface
        : (isDark
              ? AppColors.darkSurfaceVariant
              : AppColors.lightSurfaceVariant);
    final foreground = filled ? theme.scaffoldBackgroundColor : onSurface;
    return Material(
      color: background,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: AppTypography.bodyLarge(
                color: foreground,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
