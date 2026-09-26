import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/features/compose/domain/poll_draft.dart';
import 'package:gramx/app/widgets/app_dialog.dart';

/// Writing a poll.
///
/// A full-height sheet rather than a screen: a poll is written *into* something
/// — a post being composed, or a conversation — and pushing a route would take
/// the writer away from the thing they were already writing.
///
/// All the rules about when a poll may be sent live in [PollDraft], which is
/// pure and tested. This owns the controllers and the layout, and asks the
/// draft whether the Create button is on.
class PollComposerSheet extends StatefulWidget {
  /// Whether the destination allows a poll whose voters are named.
  ///
  /// Telegram refuses a non-anonymous poll in a channel, so the switch is
  /// hidden there rather than offered and rejected on send.
  final bool allowsPublicVotes;

  const PollComposerSheet({super.key, this.allowsPublicVotes = true});

  /// Opens the sheet. Returns the poll to send, or null if it was abandoned.
  static Future<PollDraft?> show(
    BuildContext context, {
    bool allowsPublicVotes = true,
  }) {
    return showModalBottomSheet<PollDraft>(
      context: context,
      isScrollControlled: true,
      // See mute_sheet.dart: the shell's bottom tab bar paints over each
      // branch's own Navigator, so this needs the root Navigator's Overlay.
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) =>
          PollComposerSheet(allowsPublicVotes: allowsPublicVotes),
    );
  }

  @override
  State<PollComposerSheet> createState() => _PollComposerSheetState();
}

class _PollComposerSheetState extends State<PollComposerSheet> {
  final TextEditingController _question = TextEditingController();

  /// One controller per option row, kept in step with `_draft.options`.
  ///
  /// The draft holds the strings and the controllers hold the cursors, and the
  /// two are only ever changed together — a row added to one and not the other
  /// is a field that types into the wrong option.
  final List<TextEditingController> _options = [];

  PollDraft _draft = const PollDraft();

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < PollDraft.initialOptions; i++) {
      _options.add(TextEditingController());
    }
    // A channel cannot take a named vote, so the draft starts where the
    // destination allows rather than at a setting that would be refused.
    if (!widget.allowsPublicVotes) _draft = _draft.withAnonymous(true);
  }

  @override
  void dispose() {
    _question.dispose();
    for (final controller in _options) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (!_draft.canAddOption) return;
    setState(() {
      _draft = _draft.addOption();
      _options.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (!_draft.canRemoveOption) return;
    setState(() {
      _draft = _draft.removeOption(index);
      _options.removeAt(index).dispose();
    });
  }

  Future<void> _close() async {
    if (_draft.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final discard = await showAppDialog<bool>(
      context,
      title: AppStrings.pollComposeDiscardTitle,
      body: AppStrings.pollComposeDiscardBody,
      actions: const [
        AppDialogAction(
          label: AppStrings.composeDiscardConfirm,
          value: true,
          isPrimary: true,
          isDestructive: true,
        ),
        AppDialogAction.cancel(AppStrings.composeDiscardCancel),
      ],
    );

    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final problem = _draft.error;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        // Lifts the sheet clear of the keyboard, which is up the whole time
        // somebody is writing a poll.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              _Header(
                canSend: _draft.canSend,
                onClose: _close,
                onCreate: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, _draft);
                },
                borderColor: border,
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xxxl,
                  ),
                  children: [
                    _SectionLabel(
                      text: AppStrings.pollComposeQuestionLabel,
                      color: secondary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _question,
                      autofocus: true,
                      maxLines: 3,
                      minLines: 1,
                      maxLength: PollDraft.maxQuestionLength,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTypography.body(color: primary),
                      decoration: const InputDecoration(
                        hintText: AppStrings.pollComposeQuestionHint,
                        counterText: '',
                      ),
                      onChanged: (value) =>
                          setState(() => _draft = _draft.withQuestion(value)),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionLabel(
                      text: AppStrings.pollComposeOptionsLabel,
                      color: secondary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < _options.length; i++)
                      _OptionRow(
                        key: ValueKey(_options[i]),
                        controller: _options[i],
                        number: i + 1,
                        primary: primary,
                        secondary: secondary,
                        canRemove: _draft.canRemoveOption,
                        // The quiz answer indexes the filled options, so a
                        // blank row above this one shifts what "correct" means.
                        isCorrect:
                            _draft.isQuiz &&
                            _draft.correctOptionIndex != null &&
                            _draft.correctOptionIndex == _filledIndexOf(i),
                        showCorrectToggle:
                            _draft.isQuiz && _filledIndexOf(i) != null,
                        onChanged: (value) => setState(
                          () => _draft = _draft.withOption(i, value),
                        ),
                        onRemove: () => _removeOption(i),
                        onMarkCorrect: () => setState(
                          () => _draft = _draft.withCorrectOption(
                            _filledIndexOf(i),
                          ),
                        ),
                      ),
                    if (_draft.canAddOption)
                      TextButton.icon(
                        onPressed: _addOption,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(AppStrings.pollComposeAddOption),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accent,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    if (widget.allowsPublicVotes)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _draft.isAnonymous,
                        title: const Text(AppStrings.pollComposeAnonymous),
                        subtitle: const Text(
                          AppStrings.pollComposeAnonymousBody,
                        ),
                        onChanged: (value) => setState(
                          () => _draft = _draft.withAnonymous(value),
                        ),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _draft.isQuiz,
                      title: const Text(AppStrings.pollComposeQuizMode),
                      subtitle: const Text(AppStrings.pollComposeQuizModeBody),
                      onChanged: (value) => setState(
                        () => _draft = _draft.withKind(
                          value ? PollKind.quiz : PollKind.regular,
                        ),
                      ),
                    ),
                    // A quiz has exactly one right answer, so it cannot also
                    // take several. The switch goes rather than sitting there
                    // disabled.
                    if (!_draft.isQuiz)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _draft.allowsMultipleAnswers,
                        title: const Text(AppStrings.pollComposeMultiple),
                        subtitle: const Text(AppStrings.pollComposeMultipleBody),
                        onChanged: (value) => setState(
                          () => _draft = _draft.withMultipleAnswers(value),
                        ),
                      ),
                    if (problem != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          AppStrings.pollComposeProblem(problem),
                          style: AppTypography.timestamp(color: secondary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Where option [index] sits once the blank rows are dropped, or null if it
  /// is itself blank. This is the index a quiz answer is recorded against.
  int? _filledIndexOf(int index) {
    if (index >= _draft.options.length) return null;
    if (_draft.options[index].trim().isEmpty) return null;
    var filled = 0;
    for (var i = 0; i < index; i++) {
      if (_draft.options[i].trim().isNotEmpty) filled++;
    }
    return filled;
  }
}

class _Header extends StatelessWidget {
  final bool canSend;
  final VoidCallback onClose;
  final VoidCallback onCreate;
  final Color borderColor;

  const _Header({
    required this.canSend,
    required this.onClose,
    required this.onCreate,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: AppStrings.composeClose,
              icon: const Icon(Icons.close_rounded),
              onPressed: onClose,
            ),
            Expanded(
              child: Text(
                AppStrings.pollComposeTitle,
                style: AppTypography.subheading(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: canSend ? onCreate : null,
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              child: const Text(AppStrings.pollComposeCreate),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.timestamp(
        color: color,
      ).copyWith(letterSpacing: 0.6, fontWeight: FontWeight.w700),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final TextEditingController controller;
  final int number;
  final Color primary;
  final Color secondary;
  final bool canRemove;
  final bool isCorrect;
  final bool showCorrectToggle;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMarkCorrect;

  const _OptionRow({
    super.key,
    required this.controller,
    required this.number,
    required this.primary,
    required this.secondary,
    required this.canRemove,
    required this.isCorrect,
    required this.showCorrectToggle,
    required this.onChanged,
    required this.onRemove,
    required this.onMarkCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          if (showCorrectToggle)
            IconButton(
              tooltip: AppStrings.pollComposeMarkCorrect,
              icon: Icon(
                isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isCorrect ? Colors.green : secondary,
                size: 20,
              ),
              onPressed: onMarkCorrect,
            ),
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: PollDraft.maxOptionLength,
              textCapitalization: TextCapitalization.sentences,
              style: AppTypography.body(color: primary),
              decoration: InputDecoration(
                hintText: AppStrings.pollComposeOptionHint(number),
                counterText: '',
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
          if (canRemove)
            IconButton(
              tooltip: AppStrings.pollComposeRemoveOption,
              icon: Icon(Icons.close_rounded, size: 18, color: secondary),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
