import 'package:handy_tdlib/api.dart' as td;

import 'package:gramx/core/l10n/app_strings.dart';

/// What the feed does with a message, by its content type.
enum ContentHandling {
  /// The post mapper draws it in full.
  rendered,

  /// Telegram's notice about the chat itself. Dropped from the feed.
  service,

  /// Real content the feed can name but cannot draw yet. Shown as a label.
  labelled,

  /// TDLib cannot represent the message, so the user is sent to Telegram.
  unrepresentable,
}

/// How one content type is handled, and the label it carries if any.
typedef ContentSupport = ({ContentHandling handling, String? label});

/// Classifies each message content type for the feed. The switch has no
/// `default`, so a new TDLib content type fails `flutter analyze` until it is
/// classified here.
abstract class MessageContentSupport {
  static const ContentSupport _rendered = (
    handling: ContentHandling.rendered,
    label: null,
  );
  static const ContentSupport _service = (
    handling: ContentHandling.service,
    label: null,
  );

  static ContentSupport _labelled(String label) =>
      (handling: ContentHandling.labelled, label: label);

  /// The single source of truth for this class.
  static ContentSupport supportFor(td.MessageContent content) {
    return switch (content) {
      // Drawn in full
      td.MessageText() => _rendered,
      td.MessagePhoto() => _rendered,
      td.MessageVideo() => _rendered,
      td.MessageVideoNote() => _rendered,
      td.MessageAnimation() => _rendered,
      td.MessageDocument() => _rendered,
      td.MessageVoiceNote() => _rendered,
      td.MessageAudio() => _rendered,
      td.MessagePoll() => _rendered,
      td.MessageSticker() => _rendered,

      // Named, not drawn
      td.MessageLocation() => _labelled('📍 Location'),
      td.MessageVenue() => _labelled('📍 Venue'),
      td.MessageContact() => _labelled('👤 Contact'),
      td.MessageDice() => _labelled('🎲 Dice'),
      td.MessageGame() => _labelled('🎮 Game'),
      td.MessageInvoice() => _labelled('🧾 Invoice'),
      td.MessageStory() => _labelled('📖 Story'),
      td.MessagePaidMedia() => _labelled('🔒 Paid media'),
      td.MessageCall() => _labelled('📞 Call'),
      // Shows the emoji itself when there is one.
      td.MessageAnimatedEmoji(:final emoji) => _labelled(
        emoji.isNotEmpty ? emoji : '😀 Animated emoji',
      ),

      // Self-destructing media whose content is gone.
      td.MessageExpiredPhoto() => _labelled('📷 Photo expired'),
      td.MessageExpiredVideo() => _labelled('🎬 Video expired'),
      td.MessageExpiredVideoNote() => _labelled('🎥 Video message expired'),
      td.MessageExpiredVoiceNote() => _labelled('🎤 Voice message expired'),

      // Giveaways and gifts.
      td.MessageGiveaway() => _labelled('🎁 Giveaway'),
      td.MessageGiveawayWinners() => _labelled('🎁 Giveaway results'),
      td.MessageGiveawayCompleted() => _labelled('🎁 Giveaway ended'),
      td.MessageGiveawayPrizeStars() => _labelled('⭐ Giveaway prize'),
      td.MessageGiftedPremium() => _labelled('🎁 Gifted Telegram Premium'),
      td.MessagePremiumGiftCode() => _labelled('🎁 Telegram Premium gift'),
      td.MessageGiftedStars() => _labelled('⭐ Gifted Telegram Stars'),

      // Service notices, dropped
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
      td.MessageChatBoost() => _service,
      // The giveaway announcement; the giveaway post itself is labelled.
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
      // Payments, bot plumbing and Passport.
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

      // TDLib cannot represent it
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

  /// A short label for real content the feed cannot draw yet. Null for
  /// content that is rendered or dropped.
  static String? describe(td.MessageContent content) =>
      supportFor(content).label;

  /// Content this build cannot represent at all (`messageUnsupported`).
  static bool isUnsupported(td.MessageContent content) =>
      supportFor(content).handling == ContentHandling.unrepresentable;

  /// The label for content this build cannot represent.
  static const String unsupportedLabel = AppStrings.postUnsupported;

  /// Whether this message should appear in the feed at all.
  static bool belongsInFeed(td.MessageContent content) =>
      !isServiceMessage(content);
}
