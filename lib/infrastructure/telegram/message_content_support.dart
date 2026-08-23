import 'package:handy_tdlib/api.dart' as td;

/// What to do with a message whose content the feed cannot render as a card.
///
/// `mapMessageToPost` only builds text and media for the content types it knows.
/// Everything else used to fall through with no text and no media, producing a
/// card with a header, a timestamp, an action bar, and nothing in between.
/// Channel history is full of these — round video messages, locations,
/// giveaways, and the service messages Telegram inserts for pins and renames.
abstract class MessageContentSupport {
  /// Content types the post mapper renders in full.
  static bool isRendered(td.MessageContent content) {
    return content is td.MessageText ||
        content is td.MessagePhoto ||
        content is td.MessageVideo ||
        content is td.MessageAnimation ||
        content is td.MessageDocument ||
        content is td.MessageVoiceNote ||
        content is td.MessageAudio ||
        content is td.MessagePoll ||
        content is td.MessageSticker;
  }

  /// Service messages: Telegram's own notices about the chat itself.
  ///
  /// These are noise in a reading feed — nobody scrolls a timeline to learn
  /// that a channel photo changed — so they are dropped rather than labelled.
  static bool isServiceMessage(td.MessageContent content) {
    return content is td.MessageChatChangeTitle ||
        content is td.MessageChatChangePhoto ||
        content is td.MessageChatDeletePhoto ||
        content is td.MessageChatAddMembers ||
        content is td.MessageChatJoinByLink ||
        content is td.MessageChatJoinByRequest ||
        content is td.MessageChatDeleteMember ||
        content is td.MessageChatUpgradeTo ||
        content is td.MessageChatUpgradeFrom ||
        content is td.MessagePinMessage ||
        content is td.MessageScreenshotTaken ||
        content is td.MessageChatSetBackground ||
        content is td.MessageChatSetTheme ||
        content is td.MessageChatSetMessageAutoDeleteTime ||
        content is td.MessageCustomServiceAction ||
        content is td.MessageContactRegistered ||
        content is td.MessageVideoChatStarted ||
        content is td.MessageVideoChatEnded ||
        content is td.MessageInviteVideoChatParticipants ||
        content is td.MessageVideoChatScheduled ||
        content is td.MessageForumTopicCreated ||
        content is td.MessageForumTopicEdited ||
        content is td.MessageForumTopicIsClosedToggled ||
        content is td.MessageForumTopicIsHiddenToggled;
  }

  /// A short human label for real content the feed cannot draw yet.
  ///
  /// Returns null for content that is rendered properly, or that should be
  /// dropped. The label is deliberately plain — it tells the reader something
  /// is there and what kind of thing it is, which beats an empty card.
  static String? describe(td.MessageContent content) {
    if (isRendered(content) || isServiceMessage(content)) return null;

    return switch (content) {
      td.MessageVideoNote() => '🎥 Video message',
      td.MessageLocation() => '📍 Location',
      td.MessageVenue() => '📍 Venue',
      td.MessageContact() => '👤 Contact',
      td.MessageDice() => '🎲 Dice',
      td.MessageGame() => '🎮 Game',
      td.MessageInvoice() => '🧾 Invoice',
      td.MessageGiveaway() => '🎁 Giveaway',
      td.MessageGiveawayWinners() => '🎁 Giveaway results',
      td.MessageGiveawayCompleted() => '🎁 Giveaway ended',
      td.MessageStory() => '📖 Story',
      td.MessagePaidMedia() => '🔒 Paid media',
      td.MessageAnimatedEmoji() => '😀 Animated emoji',
      td.MessageUnsupported() => unsupportedLabel,
      _ => unsupportedLabel,
    };
  }

  /// Content we have no card for at all.
  ///
  /// Distinct from content we can *label* — a location or a giveaway is a known
  /// thing with a known name, whereas `messageUnsupported` is TDLib telling us
  /// this build cannot represent the message. Only the latter is worth sending
  /// the reader to Telegram for.
  static bool isUnsupported(td.MessageContent content) {
    if (isRendered(content) || isServiceMessage(content)) return false;
    return describe(content) == unsupportedLabel;
  }

  /// The label for content this build cannot represent.
  static const String unsupportedLabel =
      'Unsupported message — open in Telegram to view';

  /// Whether this message should appear in the feed at all.
  static bool belongsInFeed(td.MessageContent content) =>
      !isServiceMessage(content);
}
