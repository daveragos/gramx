import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gramx/app/theme/app_colors.dart';
import 'package:gramx/app/theme/app_spacing.dart';
import 'package:gramx/app/theme/app_typography.dart';
import 'package:gramx/core/l10n/app_strings.dart';
import 'package:gramx/core/widgets/text_entity_renderer.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';
import 'package:gramx/features/trok/data/trok_client.dart';
import 'package:gramx/features/trok/data/trok_wire.dart';
import 'package:gramx/features/trok/domain/trok_models.dart';
import 'package:gramx/features/trok/presentation/trok_controller.dart';
import 'package:gramx/features/trok/presentation/widgets/trok_mark.dart';

enum InlineTranslationStatus { idle, loading, done, failed }

/// A post's translation, shown under it in the feed.
@immutable
class InlineTranslation {
  final InlineTranslationStatus status;
  final TrokText? text;

  /// Why it failed, as Trok said it.
  final String? failure;

  /// Whether the translation is open under the post.
  final bool shown;

  const InlineTranslation({
    this.status = InlineTranslationStatus.idle,
    this.text,
    this.failure,
    this.shown = false,
  });
}

/// Each post's translation, kept for the session so it opens again at once
/// and isn't asked for twice.
final inlineTranslationProvider =
    NotifierProvider.family<
      InlineTranslationNotifier,
      InlineTranslation,
      String
    >(InlineTranslationNotifier.new);

class InlineTranslationNotifier extends Notifier<InlineTranslation> {
  /// The post's id (the family argument).
  final String postId;

  InlineTranslationNotifier(this.postId);

  StreamSubscription<TrokEvent>? _answer;

  @override
  InlineTranslation build() {
    ref.onDispose(() => _answer?.cancel());
    return const InlineTranslation();
  }

  /// Opens the translation, asking Trok for it the first time.
  void show(Post post) {
    if (state.status == InlineTranslationStatus.done) {
      state = InlineTranslation(
        status: state.status,
        text: state.text,
        shown: true,
      );
      return;
    }
    if (state.status == InlineTranslationStatus.loading) return;
    state = const InlineTranslation(
      status: InlineTranslationStatus.loading,
      shown: true,
    );

    final client = ref.read(trokClientProvider);
    TrokText? last;
    String? conversationId;
    _answer = client
        .ask(
          TrokRequest(
            prompt: AppStrings.trokPostTranslatePrompt,
            post: _public(post),
            action: TrokPostAction.translate,
          ),
        )
        .listen(
          (event) {
            if (event is TrokStarted) conversationId = event.conversationId;
            if (event is TrokText) last = event;
          },
          onError: (Object error) {
            _answer = null;
            state = InlineTranslation(
              status: InlineTranslationStatus.failed,
              // Trok's own words when they say something the reader can
              // act on, such as the daily limit; else a plain line.
              failure: switch (error) {
                TrokFailure(code: 'rate_limited' || 'blocked') => error.message,
                _ => null,
              },
              shown: true,
            );
            ref.invalidate(trokAllowanceProvider);
          },
          onDone: () {
            _answer = null;
            final text = last;
            state = text == null || text.text.trim().isEmpty
                ? const InlineTranslation(
                    status: InlineTranslationStatus.failed,
                    shown: true,
                  )
                : InlineTranslation(
                    status: InlineTranslationStatus.done,
                    text: text,
                    shown: state.shown,
                  );
            ref.invalidate(trokAllowanceProvider);
            // The translation shows under the post, so it needn't also be
            // a chat in History.
            final id = conversationId;
            if (id != null) {
              unawaited(
                client
                    .deleteConversation(id)
                    .catchError(
                      (Object e) =>
                          debugPrint('[Trok] translation chat kept: $e'),
                    ),
              );
            }
          },
          cancelOnError: true,
        );
  }

  void hide() => state = InlineTranslation(
    status: state.status,
    text: state.text,
    failure: state.failure,
  );

  /// [post] with its channel's username, so Trok can share a public post's
  /// translation between readers.
  Post _public(Post post) {
    if ((post.channelUsername ?? '').isNotEmpty) return post;
    final username = ref.read(trokChannelUsernameProvider)(post.chatId);
    return username == null ? post : post.copyWith(channelUsername: username);
  }
}

/// "Translate post" under a post in another language than the reader's, and
/// the translation once asked for.
class TrokInlineTranslation extends ConsumerWidget {
  final Post post;
  final TextStyle style;

  const TrokInlineTranslation({
    super.key,
    required this.post,
    required this.style,
  });

  /// Whether [post] gets the link at all: a signed-in reader whom Trok
  /// serves, and enough words in another language.
  static bool offered(WidgetRef ref, Post post) {
    final text = post.text ?? '';
    if (text.isEmpty) return false;
    final language = ref.watch(trokAnswerLanguageProvider);
    if (!TrokWire.needsTranslation(text, language)) return false;
    if (!ref.watch(readerCapabilitiesProvider).canMessage) return false;
    return !ref.watch(trokControllerProvider.select((s) => s.blocked != null));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!offered(ref, post)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final translation = ref.watch(inlineTranslationProvider(post.id));
    final notifier = ref.read(inlineTranslationProvider(post.id).notifier);
    final link = AppTypography.actionCount(
      color: AppColors.accent,
    ).copyWith(fontSize: 14);

    Widget action(String label, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(label, style: link),
      ),
    );

    final text = translation.text;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: switch (translation) {
        InlineTranslation(status: InlineTranslationStatus.loading) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              const TrokMark(size: 16, motion: TrokMarkMotion.thinking),
              const SizedBox(width: AppSpacing.xs),
              Text(
                AppStrings.trokTranslating,
                style: AppTypography.actionCount(
                  color: secondary,
                ).copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
        InlineTranslation(
          status: InlineTranslationStatus.failed,
          shown: true,
        ) =>
          Row(
            children: [
              Flexible(
                child: Text(
                  translation.failure ?? AppStrings.trokTranslateFailed,
                  style: AppTypography.actionCount(
                    color: secondary,
                  ).copyWith(fontSize: 14),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              action(AppStrings.trokRetry, () => notifier.show(post)),
            ],
          ),
        InlineTranslation(shown: true) when text != null => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const TrokMark(size: 14),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  AppStrings.trokTranslatedBy,
                  style: AppTypography.actionCount(color: secondary),
                ),
                Text(
                  AppStrings.inlineSeparator,
                  style: AppTypography.actionCount(color: secondary),
                ),
                action(AppStrings.trokHideTranslation, notifier.hide),
              ],
            ),
            TextEntityRenderer(
              text: text.text,
              entities: text.entities,
              style: style,
            ),
          ],
        ),
        _ => Align(
          alignment: AlignmentDirectional.centerStart,
          child: action(
            text == null
                ? AppStrings.trokTranslatePost
                : AppStrings.trokShowTranslation,
            () => notifier.show(post),
          ),
        ),
      },
    );
  }
}
