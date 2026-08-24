import 'package:handy_tdlib/api.dart' as td;

/// What the feed does with a message, by its content type.
enum ContentHandling {
  /// The post mapper draws it in full.
  rendered,

  /// Telegram's own notice about the chat itself. Dropped from the feed —
  /// nobody scrolls a timeline to learn that a channel photo changed.
  service,

  /// Real content the feed can name but cannot draw yet. Gets a plain label,
  /// which beats an empty card.
  labelled,

  /// TDLib itself says this build cannot represent the message. The only case
  /// worth sending the reader to Telegram for.
  unrepresentable,
}

/// How one content type is handled, and the label it carries if any.
typedef ContentSupport = ({ContentHandling handling, String? label});

/// What to do with a message whose content the feed cannot render as a card.
///
/// `mapMessageToPost` only builds text and media for the content types it
/// knows. Everything else used to fall through with no text and no media,
/// producing a card with a header, a timestamp, an action bar, and nothing in
/// between.
///
/// The classification is **one exhaustive switch** over a sealed class, with no
/// `default` branch. That is deliberate and load-bearing: the previous version
/// named fourteen of TDLib's seventy-three content types and swept the rest
/// into `_ => unsupportedLabel`, so twenty perfectly real things — a channel
/// boost, a giveaway announcement, a gifted subscription, an expired photo —
/// arrived in the feed reading "Unsupported message — open in Telegram to
/// view". Without a `default`, the next TDLib upgrade that adds a content type
/// fails `flutter analyze` instead of quietly reaching a reader.
abstract class MessageContentSupport {
  static const ContentSupport _rendered =
      (handling: ContentHandling.rendered, label: null);
  static const ContentSupport _service =
      (handling: ContentHandling.service, label: null);

  static ContentSupport _labelled(String label) =>
      (handling: ContentHandling.labelled, label: label);

  /// The single source of truth. Everything else on this class derives from it.
  static ContentSupport supportFor(td.MessageContent content) {
    return switch (content) {
      // — Drawn in full ————————————————————————————————————————————————
      td.MessageText() => _rendered,
      td.MessagePhoto() => _rendered,
      td.MessageVideo() => _rendered,
      // A round video note is a video with a circular mask. It was labelled
      // rather than drawn, so a channel that posts them showed a line of text
      // where the video was.
      td.MessageVideoNote() => _rendered,
      td.MessageAnimation() => _rendered,
      td.MessageDocument() => _rendered,
      td.MessageVoiceNote() => _rendered,
      td.MessageAudio() => _rendered,
      td.MessagePoll() => _rendered,
      td.MessageSticker() => _rendered,

      // — Named, not drawn —————————————————————————————————————————————
      td.MessageLocation() => _labelled('📍 Location'),
      td.MessageVenue() => _labelled('📍 Venue'),
      td.MessageContact() => _labelled('👤 Contact'),
      td.MessageDice() => _labelled('🎲 Dice'),
      td.MessageGame() => _labelled('🎮 Game'),
      td.MessageInvoice() => _labelled('🧾 Invoice'),
      td.MessageStory() => _labelled('📖 Story'),
      td.MessagePaidMedia() => _labelled('🔒 Paid media'),
      td.MessageCall() => _labelled('📞 Call'),
      // It carries the emoji it animates, so the card can show the thing
      // itself rather than the words "animated emoji".
      td.MessageAnimatedEmoji(:final emoji) =>
        _labelled(emoji.isNotEmpty ? emoji : '😀 Animated emoji'),

      // Self-destructing media. The content is genuinely gone, so saying so is
      // the whole of what can be said.
      td.MessageExpiredPhoto() => _labelled('📷 Photo expired'),
      td.MessageExpiredVideo() => _labelled('🎬 Video expired'),
      td.MessageExpiredVideoNote() => _labelled('🎥 Video message expired'),
      td.MessageExpiredVoiceNote() => _labelled('🎤 Voice message expired'),

      // Giveaways and gifts. Channels post these constantly, and every one of
      // them used to read as an unsupported message.
      td.MessageGiveaway() => _labelled('🎁 Giveaway'),
      td.MessageGiveawayWinners() => _labelled('🎁 Giveaway results'),
      td.MessageGiveawayCompleted() => _labelled('🎁 Giveaway ended'),
      td.MessageGiveawayPrizeStars() => _labelled('⭐ Giveaway prize'),
      td.MessageGiftedPremium() => _labelled('🎁 Gifted Telegram Premium'),
      td.MessagePremiumGiftCode() => _labelled('🎁 Telegram Premium gift'),
      td.MessageGiftedStars() => _labelled('⭐ Gifted Telegram Stars'),

      // — Service notices, dropped —————————————————————————————————————
      td.MessageBasicGroupChatCreate() => _service,
      td.MessageSupergroupChatCreate() => _service,
      td.MessageChatChangeTitle() => _service,
      td.MessageChatChangePhoto() => _service,
      td.MessageChatDeletePhoto() => _service,
      td.MessageChatAddMembers() => _service,
      td.MessageChatJoinByLink() => _service,
      td.MessageChatJoinByRequest() => _service,
      td.MessageChatDeleteMember() => _service,
      td.MessageChatUpgradeTo() => _service,
      td.MessageChatUpgradeFrom() => _service,
      td.MessagePinMessage() => _service,
      td.MessageScreenshotTaken() => _service,
      td.MessageChatSetBackground() => _service,
      td.MessageChatSetTheme() => _service,
      td.MessageChatSetMessageAutoDeleteTime() => _service,
      // channel generates several times a day.
      td.MessageChatBoost() => _service,
      // The announcement that a giveaway is coming, as distinct from the
      // giveaway post itself, which is labelled above.
      td.MessageGiveawayCreated() => _service,
      td.MessageForumTopicCreated() => _service,
      td.MessageForumTopicEdited() => _service,
      td.MessageForumTopicIsClosedToggled() => _service,
      td.MessageForumTopicIsHiddenToggled() => _service,
      td.MessageSuggestProfilePhoto() => _service,
      td.MessageCustomServiceAction() => _service,
      td.MessageContactRegistered() => _service,
      td.MessageVideoChatStarted() => _service,
      td.MessageVideoChatEnded() => _service,
      td.MessageVideoChatScheduled() => _service,
      td.MessageInviteVideoChatParticipants() => _service,
      td.MessageGameScore() => _service,
      td.MessageProximityAlertTriggered() => _service,
      // Payments, bot plumbing and Passport. None of it belongs in a reading
      // feed, and most of it cannot occur in a channel at all.
      td.MessagePaymentSuccessful() => _service,
      td.MessagePaymentSuccessfulBot() => _service,
      td.MessagePaymentRefunded() => _service,
      td.MessageUsersShared() => _service,
      td.MessageChatShared() => _service,
      td.MessageBotWriteAccessAllowed() => _service,
      td.MessageWebAppDataSent() => _service,
      td.MessageWebAppDataReceived() => _service,
      td.MessagePassportDataSent() => _service,
      td.MessagePassportDataReceived() => _service,

      // — TDLib cannot represent it ————————————————————————————————————
      td.MessageUnsupported() => (
          handling: ContentHandling.unrepresentable,
          label: unsupportedLabel,
        ),
    };
  }

  /// Content types the post mapper renders in full.
  static bool isRendered(td.MessageContent content) =>
      supportFor(content).handling == ContentHandling.rendered;

  /// Service messages: Telegram's own notices about the chat itself.
  static bool isServiceMessage(td.MessageContent content) =>
      supportFor(content).handling == ContentHandling.service;

  /// A short human label for real content the feed cannot draw yet.
  ///
  /// Returns null for content that is rendered properly, or that should be
  /// dropped. The label is deliberately plain — it tells the reader something
  /// is there and what kind of thing it is, which beats an empty card.
  static String? describe(td.MessageContent content) => supportFor(content).label;

  /// Content we have no card for at all.
  ///
  /// Distinct from content we can *label* — a location or a giveaway is a known
  /// thing with a known name, whereas `messageUnsupported` is TDLib telling us
  /// this build cannot represent the message. Only the latter is worth sending
  /// the reader to Telegram for.
  static bool isUnsupported(td.MessageContent content) =>
      supportFor(content).handling == ContentHandling.unrepresentable;

  /// The label for content this build cannot represent.
  static const String unsupportedLabel =
      'Unsupported message — open in Telegram to view';

  /// Whether this message should appear in the feed at all.
  static bool belongsInFeed(td.MessageContent content) =>
      !isServiceMessage(content);
}
