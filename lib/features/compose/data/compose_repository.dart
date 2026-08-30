import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/features/compose/domain/compose_attachment.dart';
import 'package:gramx/features/compose/domain/compose_draft.dart';
import 'package:gramx/features/compose/domain/compose_remote_media.dart';
import 'package:gramx/features/compose/domain/compose_target.dart';
import 'package:gramx/infrastructure/telegram/chat_cache.dart';
import 'package:gramx/infrastructure/telegram/tdlib_service.dart';

/// Turns the chat cache into a list of places a post can go.
///
/// Pure, because the interesting part is the ordering rule and that is worth a
/// test: gramX is a channel reader, so a writer's own channels come first, and
/// the person they messaged yesterday does not — even though TDLib's chat list
/// puts them at the top, which is the order the forward picker uses and the
/// wrong one here.
abstract class ComposeTargets {
  /// Builds the picker's list from [chats].
  ///
  /// [chats] is expected to be `ChatCache.forwardTargets` — chats this account
  /// can actually write in. Passing everything would offer destinations that
  /// can only fail, which is the bug `canPostIn` was added to fix.
  ///
  /// [selfUserId] is the account's own Telegram user id, and it is the only way
  /// to tell Saved Messages from a chat with somebody else: TDLib models it as
  /// a private chat with yourself. Null when the account record hasn't loaded,
  /// in which case it simply reads as a direct chat.
  static List<ComposeTarget> fromChats(
    List<td.Chat> chats, {
    int? selfUserId,
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
        ),
    ];

    // Kind first, recency second. Sorting by recency alone buries the channel
    // somebody opened this screen to post in under every group that happened to
    // be busier today.
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

/// Turns a draft into the TDLib content objects that carry it.
///
/// Pure and separate from the sending, because this is where the shape of a
/// post is decided and the shapes are easy to get subtly wrong:
///
/// * nothing attached is a text message;
/// * one file is a message *with a caption*;
/// * two or more is an album whose caption belongs to the **first item only** —
///   the same caption on every item repeats it under each picture in every
///   Telegram client;
/// * a sticker or GIF is exactly one message and never an album, because
///   `sendMessageAlbum` groups only audio, document, photo and video.
/// What a send left behind for the progress bar to watch.
///
/// TDLib answers a send the moment the message is *queued*, and any attached
/// file uploads after that — so "accepted" is where the composer's job ends and
/// the progress bar's begins. These are the two things it needs: which messages
/// to wait on, and which files are still going up.
@immutable
class ComposeSendResult {
  /// The temporary message ids TDLib assigned. `updateMessageSendSucceeded`
  /// reports each one back as `oldMessageId`, which is how a finish is
  /// recognised.
  final List<int> messageIds;

  /// The files being uploaded, if any. Empty for a text post, and for a
  /// sticker or GIF already on Telegram's servers — neither uploads anything,
  /// so neither has a fraction to show.
  final List<int> fileIds;

  /// False when TDLib refused the send outright.
  final bool accepted;

  const ComposeSendResult({
    required this.accepted,
    this.messageIds = const [],
    this.fileIds = const [],
  });

  static const refused = ComposeSendResult(accepted: false);

  /// Whether anything is actually going up. A text post is accepted and has
  /// nothing to measure.
  bool get hasUpload => fileIds.isNotEmpty;
}

abstract class ComposeMessages {
  /// The files a just-queued message is still uploading.
  ///
  /// A message TDLib has accepted carries its content with the local file
  /// already attached, so the ids are there to be read — no request needed.
  /// Only the kinds the composer can attach are named; anything else has
  /// nothing being uploaded on its behalf and contributes no id.
  ///
  /// The *largest* photo size is the one that takes the time, and the smaller
  /// ones are generated from it, so counting only the largest keeps the
  /// fraction honest rather than averaging a thumbnail's instant completion
  /// against the real upload.
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
      // A sticker is already on Telegram's servers; nothing goes up for it.
      _ => const [],
    };
  }


  /// Builds one content object per message to send.
  ///
  /// Length is not checked here — [ComposeDraft.canPost] is what stands between
  /// a writer and a rejected send, and it does so before the button lights up.
  static List<td.InputMessageContent> build({
    required String text,
    required List<ComposeAttachment> attachments,
    ComposeRemoteMedia? remote,
  }) {
    final caption = text.isEmpty
        ? null
        : td.FormattedText(text: text, entities: const []);

    // A sticker or GIF replaces the whole media selection — see
    // ComposeDraft.withRemote — so it is answered before anything else.
    if (remote != null) return [_remoteContent(remote, caption: caption)];

    if (attachments.isEmpty) {
      return [
        td.InputMessageText(
          // A caption-less text post still needs its text, so this reads the
          // formatted text directly rather than the nullable caption above.
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

  /// Whether these contents go out as an album rather than a single message.
  static bool isAlbum(List<td.InputMessageContent> contents) =>
      contents.length >= ComposeLimits.minAlbumAttachments;

  static td.InputMessageContent _remoteContent(
    ComposeRemoteMedia media, {
    td.FormattedText? caption,
  }) {
    // Already on Telegram's servers: referenced by the file id TDLib holds
    // rather than uploaded again, so posting one moves no bytes.
    final file = td.InputFileId(id: media.fileId);

    if (media.isSticker) {
      // No caption parameter exists on this type. ComposeDraft.stickerBlocksText
      // is what stops a writer reaching here with words that would vanish.
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

    if (attachment.isPhoto) {
      return td.InputMessagePhoto(
        photo: file,
        addedStickerFileIds: const [],
        width: attachment.width,
        height: attachment.height,
        caption: caption,
        showCaptionAboveMedia: false,
        hasSpoiler: false,
      );
    }

    return td.InputMessageVideo(
      video: file,
      addedStickerFileIds: const [],
      duration: attachment.durationSeconds,
      width: attachment.width,
      height: attachment.height,
      // Deliberately false. The flag means "this file was muxed with its index
      // at the front", and gramX does not transcode or inspect for that — see
      // docs/TDLIB.md. Claiming it for a video that isn't stalls every player
      // that trusts it, including this app's own streaming path (T9-8). Telegram
      // works the real answer out server-side; a lie here it cannot undo.
      supportsStreaming: false,
      caption: caption,
      showCaptionAboveMedia: false,
      hasSpoiler: false,
    );
  }
}

/// Sends a post, and says where one may go.
class ComposeRepository {
  final TdlibService _tdlib;
  final ChatCache _chatCache;

  ComposeRepository(this._tdlib, this._chatCache);

  /// Default send options — the same ones the forward path uses.
  static const _sendOptions = td.MessageSendOptions(
    disableNotification: false,
    fromBackground: false,
    protectContent: false,
    updateOrderOfInstalledStickerSets: false,
    effectId: 0,
    sendingId: 0,
    onlyPreview: false,
  );

  /// This account's real length limits, straight from TDLib.
  ///
  /// The numbers differ by account — Telegram Premium raises the message limit
  /// to 8192 and the caption limit to 4096 — and `inputMessageText` and
  /// `inputMessagePhoto` both document themselves in terms of these two options
  /// rather than a constant. Asking is therefore both more correct than
  /// hardcoding a tier and future-proof against Telegram moving the numbers.
  ///
  /// Costs nothing: options live in TDLib's own store, filled by `updateOption`,
  /// so this never reaches the network. See `TdlibService._isLocalOnlyRequest`.
  ///
  /// Falls back to [ComposeLengthLimits.free] per option, because the free tier
  /// is the smaller pair — a fallback that under-promises can only cost a
  /// writer some room, while one that over-promises invites them past a limit
  /// the server will bounce them off.
  Future<ComposeLengthLimits> lengthLimits() async => ComposeLengthLimits(
        text: await _intOption('message_text_length_max') ??
            ComposeLengthLimits.free.text,
        caption: await _intOption('message_caption_length_max') ??
            ComposeLengthLimits.free.caption,
      );

  Future<int?> _intOption(String name) async {
    try {
      final res = await _tdlib.sendRequest(td.GetOption(name: name));
      // An option TDLib has no value for answers `optionValueEmpty`, not an
      // error — so a null here is the normal "not set yet", not a failure.
      if (res is td.OptionValueInteger && res.value > 0) return res.value;
    } catch (e) {
      debugPrint('[ComposeRepo] Could not read option $name: $e');
    }
    return null;
  }

  /// Where this account may post, best destination first.
  ///
  /// Read straight from [ChatCache], so opening the compose screen costs no
  /// requests at all.
  List<ComposeTarget> targets({int? selfUserId}) => ComposeTargets.fromChats(
        _chatCache.forwardTargets,
        selfUserId: selfUserId,
      );

  /// Sends the draft. Returns true when TDLib accepted it.
  ///
  /// "Accepted" is the honest word: TDLib answers as soon as the message is
  /// queued, and any attached file uploads *after* that. So an accepted result
  /// means the post is on its way, not that the bytes have landed — which is
  /// why the screen closes on it and hands the rest to the progress bar, the
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
        final res = await _tdlib.sendRequest(td.SendMessageAlbum(
          chatId: chatId,
          messageThreadId: 0,
          options: _sendOptions,
          inputMessageContents: contents,
        ));
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

      final res = await _tdlib.sendRequest(td.SendMessage(
        chatId: chatId,
        messageThreadId: 0,
        options: _sendOptions,
        inputMessageContent: contents.first,
      ));
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
}

/// This account's post length limits.
///
/// A future rather than a constant because it is read from TDLib. While it is
/// in flight the composer uses [ComposeLengthLimits.free], so the counter is
/// right for most accounts immediately and right for all of them a frame later.
final composeLengthLimitsProvider =
    FutureProvider<ComposeLengthLimits>((ref) async {
  return ref.watch(composeRepositoryProvider).lengthLimits();
});

final composeRepositoryProvider = Provider<ComposeRepository>((ref) {
  return ComposeRepository(
    ref.watch(tdlibServiceProvider),
    ref.watch(chatCacheProvider),
  );
});
