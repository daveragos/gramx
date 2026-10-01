import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_draft.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/domain/compose_target.dart';
import 'package:gramx/features/compose/domain/poll_draft.dart';
import 'package:gramx/features/compose/domain/voice_waveform.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Builds the list of chats a post can go to, with the user's channels first
/// rather than in TDLib's chat list order.
abstract class ComposeTargets {
  /// Builds the picker's list from [chats], normally `ChatCache.forwardTargets`.
  /// [selfUserId] identifies Saved Messages; [supergroupOf] is needed for
  /// [ComposeTarget.allowsPolls], which is false without it.
  static List<ComposeTarget> fromChats(
    List<td.Chat> chats, {
    int? selfUserId,
    td.Supergroup? Function(td.Chat chat)? supergroupOf,
  }) {
    final targets = [
      for (final chat in chats)
        ComposeTarget(
          chatId: chat.id,
          title: chat.title,
          kind: kindOf(chat, selfUserId: selfUserId),
          avatarPath: chat.photo?.small.local.path,
          avatarFileId: chat.photo?.small.id,
          mainListOrder: ChatCacheState.mainListOrder(chat),
          allowsPolls: ChatCacheState.canSendPollsIn(
            chat,
            supergroupOf?.call(chat),
          ),
        ),
    ];

    targets.sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      return b.mainListOrder.compareTo(a.mainListOrder);
    });
    return targets;
  }

  /// Which bucket a chat belongs in. See [ComposeTargetKind].
  static ComposeTargetKind kindOf(td.Chat chat, {int? selfUserId}) {
    final type = chat.type;

    if (type is td.ChatTypePrivate) {
      return selfUserId != null && type.userId == selfUserId
          ? ComposeTargetKind.savedMessages
          : ComposeTargetKind.direct;
    }
    if (type is td.ChatTypeSupergroup && type.isChannel) {
      return ComposeTargetKind.channel;
    }
    return ComposeTargetKind.group;
  }
}

/// The result of a send, for the upload progress bar. TDLib accepts a send
/// once the message is queued, and attached files upload afterwards.
@immutable
class ComposeSendResult {
  /// The temporary message ids TDLib assigned, which
  /// `updateMessageSendSucceeded` reports back as `oldMessageId`.
  final List<int> messageIds;

  /// The files being uploaded, if any.
  final List<int> fileIds;

  /// False when TDLib refused the send outright.
  final bool accepted;

  const ComposeSendResult({
    required this.accepted,
    this.messageIds = const [],
    this.fileIds = const [],
  });

  static const refused = ComposeSendResult(accepted: false);

  bool get hasUpload => fileIds.isNotEmpty;
}

/// Turns a draft into TDLib content objects. No attachments is a text
/// message, one is a captioned message, and several form an album with the
/// caption on the first item only.
abstract class ComposeMessages {
  /// The file ids a just-queued message is uploading, read from its content.
  /// For a photo only the largest size counts, since the others are generated
  /// from it.
  static List<int> uploadingFileIds(td.Message message) {
    final content = message.content;
    return switch (content) {
      td.MessagePhoto() when content.photo.sizes.isNotEmpty => [
        content.photo.sizes.last.photo.id,
      ],
      td.MessageVideo() => [content.video.video.id],
      td.MessageAnimation() => [content.animation.animation.id],
      td.MessageDocument() => [content.document.document.id],
      td.MessageAudio() => [content.audio.audio.id],
      td.MessageVoiceNote() => [content.voiceNote.voice.id],
      _ => const [],
    };
  }

  /// Builds one content object per message to send. Length is checked
  /// earlier, by [ComposeDraft.canPost].
  static List<td.InputMessageContent> build({
    required String text,
    required List<ComposeAttachment> attachments,
    ComposeRemoteMedia? remote,
  }) {
    final caption = text.isEmpty
        ? null
        : td.FormattedText(text: text, entities: const []);

    // A sticker or GIF replaces all other media (see ComposeDraft.withRemote).
    if (remote != null) return [_remoteContent(remote, caption: caption)];

    if (attachments.isEmpty) {
      return [
        td.InputMessageText(
          text: td.FormattedText(text: text, entities: const []),
          clearDraft: true,
        ),
      ];
    }

    return [
      for (var i = 0; i < attachments.length; i++)
        _contentFor(attachments[i], caption: i == 0 ? caption : null),
    ];
  }

  /// Whether these contents can be sent as one album. TDLib refuses albums
  /// that mix groups (see [_albumFamilyOf]).
  static bool isAlbum(List<td.InputMessageContent> contents) {
    if (contents.length < ComposeLimits.minAlbumAttachments) return false;

    final families = {for (final content in contents) _albumFamilyOf(content)};
    return families.length == 1 && !families.contains(null);
  }

  /// The album group of a content object, or null. Mirrors
  /// [ComposeMediaKind.albumFamily].
  static int? _albumFamilyOf(td.InputMessageContent content) =>
      switch (content) {
        td.InputMessagePhoto() || td.InputMessageVideo() => 0,
        td.InputMessageDocument() || td.InputMessageAudio() => 1,
        _ => null,
      };

  static td.InputMessageContent _remoteContent(
    ComposeRemoteMedia media, {
    td.FormattedText? caption,
  }) {
    // Already on Telegram's servers, so referenced by id instead of uploaded.
    final file = td.InputFileId(id: media.fileId);

    if (media.isSticker) {
      // Stickers take no caption; ComposeDraft.stickerBlocksText prevents one.
      return td.InputMessageSticker(
        sticker: file,
        width: media.width,
        height: media.height,
        emoji: media.emoji,
      );
    }

    return td.InputMessageAnimation(
      animation: file,
      addedStickerFileIds: const [],
      duration: media.durationSeconds,
      width: media.width,
      height: media.height,
      caption: caption,
      showCaptionAboveMedia: false,
      hasSpoiler: false,
    );
  }

  static td.InputMessageContent _contentFor(
    ComposeAttachment attachment, {
    td.FormattedText? caption,
  }) {
    final file = td.InputFileLocal(path: attachment.path);

    final selfDestruct = _selfDestructTypeOf(attachment.selfDestruct);

    if (attachment.isDocument) {
      return td.InputMessageDocument(
        document: file,
        // Lets Telegram detect the type from the content.
        disableContentTypeDetection: false,
        caption: caption,
      );
    }

    if (attachment.isVoiceNote) {
      return td.InputMessageVoiceNote(
        voiceNote: file,
        duration: attachment.durationSeconds,
        // TDLib's packed 5-bit format.
        waveform: VoiceWaveform.encode(attachment.waveform),
        caption: caption,
        selfDestructType: selfDestruct,
      );
    }

    if (attachment.isVideoNote) {
      return td.InputMessageVideoNote(
        videoNote: file,
        duration: attachment.durationSeconds,
        // The shorter side, as a centre crop would leave.
        length: attachment.width < attachment.height
            ? attachment.width
            : attachment.height,
        selfDestructType: selfDestruct,
      );
    }

    if (attachment.isPhoto) {
      return td.InputMessagePhoto(
        photo: file,
        addedStickerFileIds: const [],
        width: attachment.width,
        height: attachment.height,
        caption: caption,
        showCaptionAboveMedia: false,
        selfDestructType: selfDestruct,
        hasSpoiler: attachment.hasSpoiler,
      );
    }

    return td.InputMessageVideo(
      video: file,
      addedStickerFileIds: const [],
      duration: attachment.durationSeconds,
      width: attachment.width,
      height: attachment.height,
      // The app doesn't check whether the file is streamable, and a wrong
      // true stalls players. Telegram works it out server-side.
      supportsStreaming: false,
      caption: caption,
      showCaptionAboveMedia: false,
      selfDestructType: selfDestruct,
      hasSpoiler: attachment.hasSpoiler,
    );
  }

  /// TDLib's self-destruct type for [value], or null for ordinary media. A
  /// zero-second timer would still make the message self-destruct.
  static td.MessageSelfDestructType? _selfDestructTypeOf(SelfDestruct value) {
    if (value.isViewOnce) return const td.MessageSelfDestructTypeImmediately();
    if (value.seconds > 0) {
      return td.MessageSelfDestructTypeTimer(selfDestructTime: value.seconds);
    }
    return null;
  }

  /// The content object for a poll. `openPeriod`, `closeDate` and `isClosed`
  /// are bot-only and must stay unset.
  static td.InputMessageContent pollContent(PollDraft draft) {
    final options = draft.filledOptions;

    return td.InputMessagePoll(
      question: td.FormattedText(
        text: draft.question.trim(),
        entities: const [],
      ),
      options: [
        for (final option in options)
          td.FormattedText(text: option, entities: const []),
      ],
      isAnonymous: draft.isAnonymous,
      type: draft.isQuiz
          ? td.PollTypeQuiz(
              correctOptionId: draft.correctOptionIndex ?? 0,
              // No explanation; TDLib takes empty text for none.
              explanation: const td.FormattedText(text: '', entities: []),
            )
          : td.PollTypeRegular(
              allowMultipleAnswers: draft.allowsMultipleAnswers,
            ),
      openPeriod: 0,
      closeDate: 0,
      isClosed: false,
    );
  }
}

/// Sends posts and lists where they can go.
class ComposeRepository {
  final TdlibService _tdlib;
  final ChatCache _chatCache;

  ComposeRepository(this._tdlib, this._chatCache);

  static const _sendOptions = td.MessageSendOptions(
    disableNotification: false,
    fromBackground: false,
    protectContent: false,
    updateOrderOfInstalledStickerSets: false,
    effectId: 0,
    sendingId: 0,
    onlyPreview: false,
  );

  /// The account's length limits, read from local TDLib options since
  /// Premium raises them. Falls back to [ComposeLengthLimits.free].
  Future<ComposeLengthLimits> lengthLimits() async => ComposeLengthLimits(
    text:
        await _intOption('message_text_length_max') ??
        ComposeLengthLimits.free.text,
    caption:
        await _intOption('message_caption_length_max') ??
        ComposeLengthLimits.free.caption,
  );

  Future<int?> _intOption(String name) async {
    try {
      final res = await _tdlib.sendRequest(td.GetOption(name: name));
      // An unset option comes back as `optionValueEmpty`, not an error.
      if (res is td.OptionValueInteger && res.value > 0) return res.value;
    } catch (e) {
      debugPrint('[ComposeRepo] Could not read option $name: $e');
    }
    return null;
  }

  /// Where the account may post, best destination first.
  List<ComposeTarget> targets({int? selfUserId}) => ComposeTargets.fromChats(
    _chatCache.forwardTargets,
    selfUserId: selfUserId,
    supergroupOf: _chatCache.supergroupForChat,
  );

  /// Sends the draft. An accepted result means the message is queued; any
  /// uploads continue afterwards and are tracked by the progress bar.
  Future<ComposeSendResult> send({
    required int chatId,
    required String text,
    List<ComposeAttachment> attachments = const [],
    ComposeRemoteMedia? remote,
  }) async {
    final contents = ComposeMessages.build(
      text: text,
      attachments: attachments,
      remote: remote,
    );

    try {
      if (ComposeMessages.isAlbum(contents)) {
        final res = await _tdlib.sendRequest(
          td.SendMessageAlbum(
            chatId: chatId,
            messageThreadId: 0,
            options: _sendOptions,
            inputMessageContents: contents,
          ),
        );
        if (res is! td.Messages) return ComposeSendResult.refused;
        final sent = res.messages;
        return ComposeSendResult(
          accepted: sent.isNotEmpty,
          messageIds: [for (final m in sent) m.id],
          fileIds: [
            for (final m in sent) ...ComposeMessages.uploadingFileIds(m),
          ],
        );
      }

      final res = await _tdlib.sendRequest(
        td.SendMessage(
          chatId: chatId,
          messageThreadId: 0,
          options: _sendOptions,
          inputMessageContent: contents.first,
        ),
      );
      if (res is! td.Message) return ComposeSendResult.refused;
      return ComposeSendResult(
        accepted: true,
        messageIds: [res.id],
        fileIds: ComposeMessages.uploadingFileIds(res),
      );
    } catch (e) {
      debugPrint('[ComposeRepo] Send failed: $e');
      return ComposeSendResult.refused;
    }
  }

  /// Sends a poll as its own message.
  Future<ComposeSendResult> sendPoll({
    required int chatId,
    required PollDraft draft,
  }) async {
    if (!draft.canSend) return ComposeSendResult.refused;

    try {
      final res = await _tdlib.sendRequest(
        td.SendMessage(
          chatId: chatId,
          messageThreadId: 0,
          options: _sendOptions,
          inputMessageContent: ComposeMessages.pollContent(draft),
        ),
      );
      if (res is! td.Message) return ComposeSendResult.refused;
      return ComposeSendResult(accepted: true, messageIds: [res.id]);
    } catch (e) {
      debugPrint('[ComposeRepo] Poll send failed: $e');
      return ComposeSendResult.refused;
    }
  }
}

/// The account's post length limits, read from TDLib. The composer uses
/// [ComposeLengthLimits.free] until it resolves.
final composeLengthLimitsProvider = FutureProvider<ComposeLengthLimits>((
  ref,
) async {
  return ref.watch(composeRepositoryProvider).lengthLimits();
});

final composeRepositoryProvider = Provider<ComposeRepository>((ref) {
  return ComposeRepository(
    ref.watch(tdlibServiceProvider),
    ref.watch(chatCacheProvider),
  );
});
