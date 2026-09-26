import 'dart:convert';

import 'package:handy_tdlib/api.dart' as td;

/// Builders for the TDLib objects tests need.
///
/// `td.Chat` and `td.Message` have several dozen required fields, so tests
/// construct them from JSON through TDLib's own `fromJson` — shorter to write
/// and it exercises the same decoding path the real client uses.
abstract class TdFixtures {
  /// TDLib's `fromJson` casts these straight to `bool`, so every key has to be
  /// present — a missing one throws "Null is not a subtype of bool".
  static const Map<String, dynamic> _permissions = {
    '@type': 'chatPermissions',
    'can_send_basic_messages': false,
    'can_send_audios': false,
    'can_send_documents': false,
    'can_send_photos': false,
    'can_send_videos': false,
    'can_send_video_notes': false,
    'can_send_voice_notes': false,
    'can_send_polls': false,
    'can_send_other_messages': false,
    'can_add_link_previews': false,
    'can_change_info': false,
    'can_invite_users': false,
    'can_pin_messages': false,
    'can_create_topics': false,
  };

  static const Map<String, dynamic> _notificationSettings = {
    '@type': 'chatNotificationSettings',
    'use_default_mute_for': true,
    'mute_for': 0,
    'use_default_sound': true,
    'sound_id': 0,
    'use_default_show_preview': true,
    'show_preview': true,
    'use_default_mute_stories': true,
    'mute_stories': false,
    'use_default_story_sound': true,
    'story_sound_id': 0,
    'use_default_show_story_sender': true,
    'show_story_sender': true,
    'disable_mention_notifications': false,
    'use_default_disable_mention_notifications': true,
    'disable_pinned_message_notifications': false,
    'use_default_disable_pinned_message_notifications': true,
  };

  static const Map<String, dynamic> _videoChat = {
    '@type': 'videoChat',
    'group_call_id': 0,
    'has_participants': false,
  };

  /// A supergroup chat. [isChannel] false makes it a group instead.
  ///
  /// [canSendBasicMessages] is the chat's default member permission, which is
  /// what decides whether a post can be forwarded into a group.
  static td.Chat chat({
    required int id,
    String title = 'Test Channel',
    bool isChannel = true,
    int mainOrder = 0,
    int unreadCount = 0,
    bool canSendBasicMessages = false,
    bool canSendPolls = false,
    bool canSendVoiceNotes = false,
    bool canSendDocuments = false,
    Map<String, dynamic>? lastMessage,
    List<Map<String, dynamic>>? positions,
  }) {
    return td.Chat.fromJson(
      _chatJson(
        id: id,
        title: title,
        isChannel: isChannel,
        mainOrder: mainOrder,
        unreadCount: unreadCount,
        canSendBasicMessages: canSendBasicMessages,
        canSendPolls: canSendPolls,
        canSendVoiceNotes: canSendVoiceNotes,
        canSendDocuments: canSendDocuments,
        lastMessage: lastMessage,
        positions: positions,
      ),
    );
  }

  /// A one-to-one chat — always a valid forward destination.
  static td.Chat privateChat({required int id, String title = 'A Person'}) {
    final json = _chatJson(id: id, title: title, mainOrder: 100);
    json['type'] = {'@type': 'chatTypePrivate', 'user_id': id.abs()};
    return td.Chat.fromJson(json);
  }

  /// The same chat, but with a photo on it.
  ///
  /// The photo is the interesting half of the comment-avatar rule: a chat that
  /// *has* one is what a commenter's missing avatar used to fall back to.
  static td.Chat chatWithPhoto({
    required int id,
    required int photoFileId,
    String title = 'Test Channel',
    String localPath = '/tmp/channel.jpg',
  }) {
    final json = _chatJson(id: id, title: title);
    json['photo'] = chatPhotoInfoJson(
      fileId: photoFileId,
      localPath: localPath,
    );
    return td.Chat.fromJson(json);
  }

  static Map<String, dynamic> chatPhotoInfoJson({
    required int fileId,
    String localPath = '/tmp/photo.jpg',
  }) => {
    '@type': 'chatPhotoInfo',
    'small': fileJson(id: fileId, localPath: localPath),
    'big': fileJson(id: fileId + 1, localPath: localPath),
    'has_animation': false,
    'is_personal': false,
  };

  static Map<String, dynamic> profilePhotoJson({
    required int fileId,
    String localPath = '/tmp/avatar.jpg',
  }) => {
    '@type': 'profilePhoto',
    'id': '$fileId',
    'small': fileJson(id: fileId, localPath: localPath),
    'big': fileJson(id: fileId + 1, localPath: localPath),
    'has_animation': false,
    'is_personal': false,
  };

  static Map<String, dynamic> fileJson({
    required int id,
    String localPath = '',
    String remoteId = '',
  }) => {
    '@type': 'file',
    'id': id,
    'size': 1024,
    'expected_size': 1024,
    'local': {
      '@type': 'localFile',
      'path': localPath,
      'can_be_downloaded': true,
      'can_be_deleted': true,
      'is_downloading_active': false,
      'is_downloading_completed': localPath.isNotEmpty,
      'download_offset': 0,
      'downloaded_prefix_size': localPath.isEmpty ? 0 : 1024,
      'downloaded_size': localPath.isEmpty ? 0 : 1024,
    },
    'remote': {
      '@type': 'remoteFile',
      'id': remoteId,
      'unique_id': remoteId,
      'is_uploading_active': false,
      'is_uploading_completed': true,
      'uploaded_size': 1024,
    },
  };

  /// A full user record. Only the fields gramX reads are interesting; the rest
  /// exist because TDLib's decoder requires them.
  static td.UserFullInfo userFullInfo({
    String? bio,
    int personalChatId = 0,
    int groupInCommonCount = 0,
  }) => td.UserFullInfo.fromJson(<String, dynamic>{
    '@type': 'userFullInfo',
    'can_be_called': false,
    'supports_video_calls': false,
    'has_private_calls': false,
    'has_private_forwards': false,
    'has_restricted_voice_and_video_note_messages': false,
    'has_posted_to_profile_stories': false,
    'has_sponsored_messages_enabled': false,
    'need_phone_number_privacy_exception': false,
    'set_chat_background': false,
    'bio': bio == null
        ? null
        : {'@type': 'formattedText', 'text': bio, 'entities': <dynamic>[]},
    'personal_chat_id': personalChatId,
    'premium_gift_options': <dynamic>[],
    'group_in_common_count': groupInCommonCount,
  });

  static Map<String, dynamic> _chatJson({
    required int id,
    String title = 'Test Channel',
    bool isChannel = true,
    int mainOrder = 0,
    int unreadCount = 0,
    bool canSendBasicMessages = false,
    bool canSendPolls = false,
    bool canSendVoiceNotes = false,
    bool canSendDocuments = false,
    Map<String, dynamic>? lastMessage,
    List<Map<String, dynamic>>? positions,
  }) => <String, dynamic>{
    '@type': 'chat',
    'id': id,
    'type': {
      '@type': 'chatTypeSupergroup',
      'supergroup_id': id.abs() % 1000000,
      'is_channel': isChannel,
    },
    'title': title,
    'accent_color_id': 0,
    'background_custom_emoji_id': 0,
    'profile_accent_color_id': 0,
    'profile_background_custom_emoji_id': 0,
    'permissions': {
      ..._permissions,
      'can_send_basic_messages': canSendBasicMessages,
      'can_send_polls': canSendPolls,
      'can_send_voice_notes': canSendVoiceNotes,
      'can_send_documents': canSendDocuments,
    },
    'last_message': lastMessage,
    'positions':
        positions ??
        (mainOrder == 0
            ? <Map<String, dynamic>>[]
            : [mainListPosition(order: mainOrder)]),
    'chat_lists': <Map<String, dynamic>>[],
    'has_protected_content': false,
    'is_translatable': false,
    'is_marked_as_unread': false,
    'view_as_topics': false,
    'has_scheduled_messages': false,
    'can_be_deleted_only_for_self': false,
    'can_be_deleted_for_all_users': false,
    'can_be_reported': false,
    'default_disable_notification': false,
    'unread_count': unreadCount,
    'last_read_inbox_message_id': 0,
    'last_read_outbox_message_id': 0,
    'unread_mention_count': 0,
    'unread_reaction_count': 0,
    'notification_settings': _notificationSettings,
    'available_reactions': {
      '@type': 'chatAvailableReactionsAll',
      'max_reaction_count': 11,
    },
    'message_auto_delete_time': 0,
    'theme_name': '',
    'video_chat': _videoChat,
    'reply_markup_message_id': 0,
    'client_data': '',
  };

  static Map<String, dynamic> mainListPosition({required int order}) => {
    '@type': 'chatPosition',
    'list': {'@type': 'chatListMain'},
    'order': order,
    'is_pinned': false,
  };

  static Map<String, dynamic> archiveListPosition({required int order}) => {
    '@type': 'chatPosition',
    'list': {'@type': 'chatListArchive'},
    'order': order,
    'is_pinned': false,
  };

  static td.ChatPosition position({required int order, bool archive = false}) {
    return td.ChatPosition.fromJson(
      archive
          ? archiveListPosition(order: order)
          : mainListPosition(order: order),
    );
  }

  /// A plain text message. [id] is the raw TDLib id (already shifted).
  static Map<String, dynamic> textMessageJson({
    required int id,
    required int chatId,
    String text = 'hello',
    int date = 1700000000,
  }) => {
    '@type': 'message',
    'id': id,
    'sender_id': {'@type': 'messageSenderChat', 'chat_id': chatId},
    'chat_id': chatId,
    'date': date,
    'is_outgoing': false,
    'is_from_offline': false,
    'is_pinned': false,
    'can_be_saved': true,
    'has_timestamped_media': false,
    'is_channel_post': true,
    'is_topic_message': false,
    'contains_unread_mention': false,
    'edit_date': 0,
    'message_thread_id': 0,
    'saved_messages_topic_id': 0,
    'self_destruct_in': 0.0,
    'auto_delete_in': 0.0,
    'via_bot_user_id': 0,
    'sender_business_bot_user_id': 0,
    'sender_boost_count': 0,
    'author_signature': '',
    'media_album_id': '0',
    'effect_id': '0',
    'has_sensitive_content': false,
    'restriction_reason': '',
    'content': {
      '@type': 'messageText',
      'text': {'@type': 'formattedText', 'text': text, 'entities': []},
    },
  };

  /// A message carrying a photo, with one `photoSize` per id given.
  ///
  /// Sizes ascend, so the last id is the largest — which is the one the upload
  /// tracker counts, and the reason this takes a list rather than one id.
  static td.Message photoMessage({
    required int id,
    required int chatId,
    required List<int> fileIds,
    String caption = '',
  }) {
    final json = textMessageJson(id: id, chatId: chatId);
    json['content'] = {
      '@type': 'messagePhoto',
      'photo': {
        '@type': 'photo',
        'has_stickers': false,
        'minithumbnail': null,
        'sizes': [
          for (var i = 0; i < fileIds.length; i++)
            {
              '@type': 'photoSize',
              'type': ['s', 'm', 'x', 'y'][i.clamp(0, 3)],
              'photo': fileJson(id: fileIds[i]),
              'width': 100 * (i + 1),
              'height': 100 * (i + 1),
              'progressive_sizes': <int>[],
            },
        ],
      },
      'caption': {
        '@type': 'formattedText',
        'text': caption,
        'entities': <Object>[],
      },
      'show_caption_above_media': false,
      'has_spoiler': false,
      'is_secret': false,
    };
    return td.Message.fromJson(json);
  }

  /// A message carrying a video.
  static td.Message videoMessage({
    required int id,
    required int chatId,
    required int fileId,
    String caption = '',
  }) {
    final json = textMessageJson(id: id, chatId: chatId);
    json['content'] = {
      '@type': 'messageVideo',
      'video': {
        '@type': 'video',
        'duration': 10,
        'width': 640,
        'height': 480,
        'file_name': 'clip.mp4',
        'mime_type': 'video/mp4',
        'has_stickers': false,
        'supports_streaming': true,
        'minithumbnail': null,
        'thumbnail': null,
        'video': fileJson(id: fileId),
      },
      'alternative_videos': <Object>[],
      'storyboards': <Object>[],
      'cover': null,
      'start_timestamp': 0,
      'caption': {
        '@type': 'formattedText',
        'text': caption,
        'entities': <Object>[],
      },
      'show_caption_above_media': false,
      'has_spoiler': false,
      'is_secret': false,
    };
    return td.Message.fromJson(json);
  }

  /// A message carrying a poll.
  ///
  /// Every field TDLib requires, because a poll bubble is the case that used to
  /// render empty — a fixture that skipped one would let that come back.
  static td.Message pollMessage({
    required int id,
    required int chatId,
    String question = 'Which one?',
    List<String> options = const ['A', 'B'],
    bool isQuiz = false,
    bool allowMultipleAnswers = false,
    bool isClosed = false,
    int? chosenIndex,
  }) {
    final json = textMessageJson(id: id, chatId: chatId);
    json['content'] = {
      '@type': 'messagePoll',
      'poll': {
        '@type': 'poll',
        'id': '$id',
        'question': {
          '@type': 'formattedText',
          'text': question,
          'entities': <Object>[],
        },
        'options': [
          for (var i = 0; i < options.length; i++)
            {
              '@type': 'pollOption',
              'text': {
                '@type': 'formattedText',
                'text': options[i],
                'entities': <Object>[],
              },
              'voter_count': i == chosenIndex ? 1 : 0,
              'vote_percentage': i == chosenIndex ? 100 : 0,
              'is_chosen': i == chosenIndex,
              'is_being_chosen': false,
            },
        ],
        'total_voter_count': chosenIndex == null ? 0 : 1,
        'recent_voter_ids': <Object>[],
        'is_anonymous': true,
        'type': isQuiz
            ? {
                '@type': 'pollTypeQuiz',
                'correct_option_id': 0,
                'explanation': {
                  '@type': 'formattedText',
                  'text': '',
                  'entities': <Object>[],
                },
              }
            : {
                '@type': 'pollTypeRegular',
                'allow_multiple_answers': allowMultipleAnswers,
              },
        'open_period': 0,
        'close_date': 0,
        'is_closed': isClosed,
      },
    };
    return td.Message.fromJson(json);
  }

  /// A photo that disappears once it is opened.
  ///
  /// [viewOnce] chooses which of TDLib's two self-destruct shapes it carries;
  /// [seconds] is the timer for the other one. `is_secret` is the flag that
  /// says it has not been opened yet, and it is what the cover is drawn from.
  static td.Message secretPhotoMessage({
    required int id,
    required int chatId,
    bool viewOnce = true,
    int seconds = 0,
    bool isSecret = true,
  }) {
    final message = photoMessage(id: id, chatId: chatId, fileIds: const [7]);
    final json =
        jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>;
    (json['content'] as Map<String, dynamic>)['is_secret'] = isSecret;
    json['self_destruct_type'] = viewOnce
        ? {'@type': 'messageSelfDestructTypeImmediately'}
        : {
            '@type': 'messageSelfDestructTypeTimer',
            'self_destruct_time': seconds,
          };
    return td.Message.fromJson(json);
  }

  /// A chat that is end-to-end encrypted.
  ///
  /// [secretChatId] is what the `SecretChat` record is keyed by — a different
  /// number from the chat id, which is the distinction the cache exists to keep
  /// straight.
  static td.Chat secretChat({
    required int id,
    required int userId,
    int secretChatId = 5,
    String title = 'A Person',
  }) {
    final json = _chatJson(id: id, title: title, mainOrder: 100);
    json['type'] = {
      '@type': 'chatTypeSecret',
      'secret_chat_id': secretChatId,
      'user_id': userId,
    };
    return td.Chat.fromJson(json);
  }

  /// The end-to-end record behind a secret chat.
  ///
  /// [isReady] is the whole point of it: a secret chat is pending until the
  /// other device finishes the key exchange, and Telegram refuses messages
  /// sent into a pending one.
  static td.UpdateSecretChat secretChatUpdate({
    int secretChatId = 5,
    required int userId,
    bool isReady = true,
  }) {
    return td.UpdateSecretChat(
      secretChat: td.SecretChat.fromJson({
        '@type': 'secretChat',
        'id': secretChatId,
        'user_id': userId,
        'state': isReady
            ? {'@type': 'secretChatStateReady'}
            : {'@type': 'secretChatStatePending'},
        'is_outbound': true,
        'key_hash': '',
        'layer': 143,
      }),
    );
  }

  /// A message carrying a plain location.
  static td.Message locationMessage({
    required int id,
    required int chatId,
    double latitude = 51.5007,
    double longitude = -0.1246,
    int livePeriod = 0,
    int expiresIn = 0,
  }) {
    final json = textMessageJson(id: id, chatId: chatId);
    json['content'] = {
      '@type': 'messageLocation',
      'location': {
        '@type': 'location',
        'latitude': latitude,
        'longitude': longitude,
        'horizontal_accuracy': 0.0,
      },
      'live_period': livePeriod,
      'expires_in': expiresIn,
      'heading': 0,
      'proximity_alert_radius': 0,
    };
    return td.Message.fromJson(json);
  }

  /// A message carrying a venue: a location with a name and an address.
  static td.Message venueMessage({
    required int id,
    required int chatId,
    String title = 'Big Ben',
    String address = 'Westminster',
  }) {
    final json = textMessageJson(id: id, chatId: chatId);
    json['content'] = {
      '@type': 'messageVenue',
      'venue': {
        '@type': 'venue',
        'location': {
          '@type': 'location',
          'latitude': 51.5007,
          'longitude': -0.1246,
          'horizontal_accuracy': 0.0,
        },
        'title': title,
        'address': address,
        'provider': 'foursquare',
        'id': '1',
        'type': '',
      },
    };
    return td.Message.fromJson(json);
  }

  /// A message carrying a contact card.
  static td.Message contactMessage({
    required int id,
    required int chatId,
    String firstName = 'Ada',
    String lastName = 'Lovelace',
    String phoneNumber = '442071234567',
    int userId = 77,
  }) {
    final json = textMessageJson(id: id, chatId: chatId);
    json['content'] = {
      '@type': 'messageContact',
      'contact': {
        '@type': 'contact',
        'phone_number': phoneNumber,
        'first_name': firstName,
        'last_name': lastName,
        'vcard': '',
        'user_id': userId,
      },
    };
    return td.Message.fromJson(json);
  }

  static td.Message textMessage({
    required int id,
    required int chatId,
    String text = 'hello',
    int date = 1700000000,
  }) => td.Message.fromJson(
    textMessageJson(id: id, chatId: chatId, text: text, date: date),
  );

  /// A channel post that answers another message.
  ///
  /// [quote] is the passage the writer *selected* out of what they answered.
  /// TDLib fills `reply_to.quote` only in that case, which is the one thing
  /// separating a quoted passage from a reply to a whole post — and the two
  /// are drawn differently, so a fixture that could not express the difference
  /// could not test it.
  ///
  /// [targetText] is the answered message's own content, which TDLib inlines
  /// for cross-chat replies and quotes. Supplying it alongside [quote] is the
  /// case that matters: both arrive, and the selected passage must win.
  static td.Message replyingMessage({
    required int id,
    required int chatId,
    required int replyToMessageId,
    String text = 'hello',
    int replyToChatId = 0,
    String? quote,
    String? targetText,
    bool targetIsPhoto = false,
    String? targetCaption,
    int? originChatId,
  }) {
    final json = textMessageJson(id: id, chatId: chatId, text: text);
    final replyTo = <String, dynamic>{
      '@type': 'messageReplyToMessage',
      'chat_id': replyToChatId,
      'message_id': replyToMessageId,
      // Non-nullable in TDLib's decoder even though it is meaningless for a
      // same-chat reply — a missing key throws "Null is not a subtype of int".
      'origin_send_date': 0,
    };
    if (quote != null) {
      replyTo['quote'] = {
        '@type': 'textQuote',
        'text': {'@type': 'formattedText', 'text': quote, 'entities': []},
        'position': 0,
        'is_manual': true,
      };
    }
    if (targetText != null) {
      replyTo['content'] = {
        '@type': 'messageText',
        'text': {'@type': 'formattedText', 'text': targetText, 'entities': []},
      };
    }
    if (targetIsPhoto) {
      replyTo['content'] = {
        '@type': 'messagePhoto',
        'photo': {
          '@type': 'photo',
          'has_stickers': false,
          'sizes': [
            {
              '@type': 'photoSize',
              'type': 'm',
              'photo': fileJson(id: 4242),
              'width': 320,
              'height': 320,
              'progressive_sizes': <int>[],
            },
          ],
        },
        'caption': {
          '@type': 'formattedText',
          'text': targetCaption ?? '',
          'entities': [],
        },
        'show_caption_above_media': false,
        'has_spoiler': false,
        'is_secret': false,
      };
    }
    if (originChatId != null) {
      replyTo['origin'] = {
        '@type': 'messageOriginChannel',
        'chat_id': originChatId,
        'message_id': replyToMessageId,
        'author_signature': '',
      };
    }
    json['reply_to'] = replyTo;
    return td.Message.fromJson(json);
  }

  /// One entry in a message's reaction list.
  ///
  /// [type] is the raw `ReactionType` JSON, so a test can build the emoji, paid
  /// and custom-emoji forms — all three appear on real channel posts and only
  /// the first used to survive the mapper.
  static Map<String, dynamic> reactionJson({
    required Map<String, dynamic> type,
    required int totalCount,
    bool isChosen = false,
  }) => {
    '@type': 'messageReaction',
    'type': type,
    'total_count': totalCount,
    'is_chosen': isChosen,
    'used_sender_id': null,
    'recent_sender_ids': <dynamic>[],
  };

  static Map<String, dynamic> emojiReactionType(String emoji) => {
    '@type': 'reactionTypeEmoji',
    'emoji': emoji,
  };

  static Map<String, dynamic> paidReactionType() => {
    '@type': 'reactionTypePaid',
  };

  static Map<String, dynamic> customEmojiReactionType(String customEmojiId) => {
    '@type': 'reactionTypeCustomEmoji',
    'custom_emoji_id': customEmojiId,
  };

  static Map<String, dynamic> messageReactionsJson(
    List<Map<String, dynamic>> reactions,
  ) => {
    '@type': 'messageReactions',
    'reactions': reactions,
    'are_tags': false,
    'paid_reactors': <dynamic>[],
    'can_get_added_reactions': false,
  };

  static td.MessageReactions messageReactions(
    List<Map<String, dynamic>> reactions,
  ) => td.MessageReactions.fromJson(messageReactionsJson(reactions));

  /// The update that actually carries reactions to a user client.
  ///
  /// `updateMessageReactions` is bots-only, so this is the only one that fires
  /// for a reader.
  static td.UpdateMessageInteractionInfo interactionInfo({
    required int chatId,
    required int messageId,
    int viewCount = 0,
    int forwardCount = 0,
    List<Map<String, dynamic>>? reactions,
  }) => td.UpdateMessageInteractionInfo(
    chatId: chatId,
    messageId: messageId,
    interactionInfo: td.MessageInteractionInfo(
      viewCount: viewCount,
      forwardCount: forwardCount,
      reactions: reactions == null ? null : messageReactions(reactions),
    ),
  );

  /// A text message carrying interaction info, as history returns it.
  static td.Message messageWithReactions({
    required int id,
    required int chatId,
    required List<Map<String, dynamic>> reactions,
    int viewCount = 0,
    String text = 'hello',
  }) {
    final json = textMessageJson(id: id, chatId: chatId, text: text);
    json['interaction_info'] = {
      '@type': 'messageInteractionInfo',
      'view_count': viewCount,
      'forward_count': 0,
      'reply_info': null,
      'reactions': messageReactionsJson(reactions),
    };
    return td.Message.fromJson(json);
  }

  /// A basic-group chat — used to check supergroup lookups degrade safely.
  static td.Chat basicGroupChat({required int id, String title = 'Group'}) {
    final json = _chatJson(id: id, title: title);
    json['type'] = {'@type': 'chatTypeBasicGroup', 'basic_group_id': id.abs()};
    return td.Chat.fromJson(json);
  }

  /// [status] is the raw `ChatMemberStatus` JSON — what decides whether the
  /// account may post into a channel.
  static td.UpdateSupergroup supergroup({
    required int id,
    int memberCount = 0,
    bool isVerified = false,
    bool isChannel = true,
    String? username,
    Map<String, dynamic>? status,
  }) => td.UpdateSupergroup(
    supergroup: td.Supergroup.fromJson(<String, dynamic>{
      '@type': 'supergroup',
      'id': id,
      'usernames': username == null
          ? null
          : {
              '@type': 'usernames',
              'active_usernames': [username],
              'disabled_usernames': <String>[],
              'editable_username': username,
            },
      'date': 0,
      'status':
          status ?? {'@type': 'chatMemberStatusMember', 'member_until_date': 0},
      'member_count': memberCount,
      'boost_level': 0,
      'has_linked_chat': false,
      'has_location': false,
      'sign_messages': false,
      'show_message_sender': false,
      'join_to_send_messages': false,
      'join_by_request': false,
      'is_slow_mode_enabled': false,
      'is_channel': isChannel,
      'is_broadcast_group': false,
      'is_forum': false,
      'is_verified': isVerified,
      'has_sensitive_content': false,
      'restriction_reason': '',
      'is_scam': false,
      'is_fake': false,
      'has_active_stories': false,
      'has_unread_active_stories': false,
    }),
  );

  static td.UpdateNewChat newChat(td.Chat chat) => td.UpdateNewChat(chat: chat);

  static td.UpdateChatLastMessage lastMessage({
    required int chatId,
    td.Message? message,
    int mainOrder = 0,
  }) => td.UpdateChatLastMessage(
    chatId: chatId,
    lastMessage: message,
    positions: mainOrder == 0
        ? const []
        : [td.ChatPosition.fromJson(mainListPosition(order: mainOrder))],
  );

  /// An admin status with the given posting right, for forward-target rules.
  static Map<String, dynamic> adminStatus({bool canPostMessages = true}) => {
    '@type': 'chatMemberStatusAdministrator',
    'custom_title': '',
    'can_be_edited': false,
    'rights': {
      '@type': 'chatAdministratorRights',
      'can_manage_chat': true,
      'can_change_info': false,
      'can_post_messages': canPostMessages,
      'can_edit_messages': false,
      'can_delete_messages': false,
      'can_invite_users': false,
      'can_restrict_members': false,
      'can_pin_messages': false,
      'can_manage_topics': false,
      'can_promote_members': false,
      'can_manage_video_chats': false,
      'can_post_stories': false,
      'can_edit_stories': false,
      'can_delete_stories': false,
      'is_anonymous': false,
    },
  };

  static Map<String, dynamic> creatorStatus() => {
    '@type': 'chatMemberStatusCreator',
    'custom_title': '',
    'is_anonymous': false,
    'is_member': true,
  };

  // ── Conversations ──────────────────────────────────────────────────────────

  /// A private chat, with everything the messages list reads off one.
  ///
  /// The plain [privateChat] above is enough for the forward picker, which only
  /// asks "can I post here". A chat *row* reads a dozen more fields — unread
  /// state, mute, draft, the action bar — and every one of them has been the
  /// difference between a correct row and a wrong one.
  static td.Chat conversation({
    required int id,
    String title = 'A Person',
    int? userId,
    int mainOrder = 100,
    int unreadCount = 0,
    bool isMarkedAsUnread = false,
    bool isPinned = false,
    int unreadMentionCount = 0,
    int lastReadInboxMessageId = 0,
    int lastReadOutboxMessageId = 0,
    bool isMuted = false,
    String? draftText,
    Map<String, dynamic>? actionBar,
    Map<String, dynamic>? lastMessage,
    Map<String, dynamic>? type,
  }) {
    final json = _chatJson(
      id: id,
      title: title,
      mainOrder: mainOrder,
      unreadCount: unreadCount,
      lastMessage: lastMessage,
    );
    json['type'] =
        type ?? {'@type': 'chatTypePrivate', 'user_id': userId ?? id.abs()};
    json['is_marked_as_unread'] = isMarkedAsUnread;
    if (isPinned) {
      json['positions'] = [
        {...mainListPosition(order: mainOrder), 'is_pinned': true},
      ];
    }
    json['unread_mention_count'] = unreadMentionCount;
    json['last_read_inbox_message_id'] = lastReadInboxMessageId;
    json['last_read_outbox_message_id'] = lastReadOutboxMessageId;
    if (isMuted) {
      json['notification_settings'] = {
        ..._notificationSettings,
        'use_default_mute_for': false,
        'mute_for': 3600,
      };
    }
    if (actionBar != null) json['action_bar'] = actionBar;
    if (draftText != null) {
      json['draft_message'] = {
        '@type': 'draftMessage',
        'date': 1700000000,
        'effect_id': '0',
        'input_message_text': {
          '@type': 'inputMessageText',
          'text': {
            '@type': 'formattedText',
            'text': draftText,
            'entities': <Map<String, dynamic>>[],
          },
          'clear_draft': false,
        },
      };
    }
    return td.Chat.fromJson(json);
  }

  /// A group chat that belongs in the messages list: a supergroup that is not
  /// a broadcast channel.
  static td.Chat groupChat({
    required int id,
    String title = 'The Group',
    int mainOrder = 100,
    Map<String, dynamic>? lastMessage,
  }) => conversation(
    id: id,
    title: title,
    mainOrder: mainOrder,
    lastMessage: lastMessage,
    type: {
      '@type': 'chatTypeSupergroup',
      'supergroup_id': id.abs() % 1000000,
      'is_channel': false,
    },
  );

  /// Telegram's "you don't know this person" bar — what the Requests filter is
  /// built on.
  static Map<String, dynamic> reportAddBlockBar() => {
    '@type': 'chatActionBarReportAddBlock',
    'can_unarchive': false,
    'distance': -1,
  };

  /// A user record, as `UpdateUser` delivers one.
  ///
  /// [status] is the raw `UserStatus` JSON. It decides the presence line, and
  /// Telegram deliberately blurs it — "last seen recently" is a real answer
  /// rather than a missing timestamp.
  static td.User user({
    required int id,
    String firstName = 'Ada',
    String lastName = '',
    String? username,
    bool isBot = false,
    bool isDeleted = false,
    bool isVerified = false,
    bool isPremium = false,
    bool isContact = false,
    String phoneNumber = '',
    int? profilePhotoFileId,
    Map<String, dynamic>? status,
  }) => td.User.fromJson(<String, dynamic>{
    '@type': 'user',
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'usernames': username == null
        ? null
        : {
            '@type': 'usernames',
            'active_usernames': [username],
            'disabled_usernames': <String>[],
            'editable_username': username,
          },
    'phone_number': phoneNumber,
    'profile_photo': profilePhotoFileId == null
        ? null
        : profilePhotoJson(fileId: profilePhotoFileId),
    'status': status ?? {'@type': 'userStatusOffline', 'was_online': 0},
    'accent_color_id': 0,
    'background_custom_emoji_id': '0',
    'profile_accent_color_id': -1,
    'profile_background_custom_emoji_id': '0',
    'is_contact': isContact,
    'is_mutual_contact': false,
    'is_close_friend': false,
    'is_verified': isVerified,
    'is_premium': isPremium,
    'is_support': false,
    'restriction_reason': '',
    'is_scam': false,
    'is_fake': false,
    'has_active_stories': false,
    'has_unread_active_stories': false,
    'restricts_new_chats': false,
    'have_access': true,
    'type': isDeleted
        ? {'@type': 'userTypeDeleted'}
        : isBot
        ? {
            '@type': 'userTypeBot',
            'can_be_edited': false,
            'can_join_groups': true,
            'can_read_all_group_messages': false,
            'has_main_web_app': false,
            'is_inline': false,
            'inline_query_placeholder': '',
            'need_location': false,
            'can_connect_to_business': false,
            'can_be_added_to_attachment_menu': false,
            'active_user_count': 0,
          }
        : {'@type': 'userTypeRegular'},
    'language_code': '',
    'added_to_attachment_menu': false,
  });

  static td.UpdateUser userUpdate(td.User user) => td.UpdateUser(user: user);

  ///
  /// A message *about* a contact rather than a conversation with one — it is
  /// the only content a chat that has never been used ever contains, which is
  /// what makes it safe to filter a whole chat on.
  static Map<String, dynamic> contactRegisteredMessageJson({
    required int id,
    required int chatId,
  }) {
    final json = textMessageJson(id: id, chatId: chatId);
    json['content'] = {'@type': 'messageContactRegistered'};
    return json;
  }

  /// A message in a conversation: sent by a person, on one side or the other.
  ///
  /// The channel-post [textMessage] above is sent by a *chat* and is never
  /// outgoing, which is the wrong shape for every assertion a conversation
  /// makes.
  static td.Message chatMessage({
    required int id,
    required int chatId,
    required int senderUserId,
    String text = 'hello',
    bool isOutgoing = false,
    int date = 1700000000,
    int editDate = 0,
    int? replyToMessageId,
    int replyToChatId = 0,
    String? sendingState,
  }) {
    final json = textMessageJson(
      id: id,
      chatId: chatId,
      text: text,
      date: date,
    );
    json['sender_id'] = {'@type': 'messageSenderUser', 'user_id': senderUserId};
    json['is_outgoing'] = isOutgoing;
    json['is_channel_post'] = false;
    json['edit_date'] = editDate;
    if (sendingState != null) {
      json['sending_state'] = sendingState == 'pending'
          ? {'@type': 'messageSendingStatePending', 'sending_id': 0}
          : {
              '@type': 'messageSendingStateFailed',
              'error': {
                '@type': 'error',
                'code': 400,
                'message': 'MESSAGE_TOO_LONG',
              },
              'can_retry': false,
              'need_another_sender': false,
              'need_another_reply_quote': false,
              'need_drop_reply': false,
              'retry_after': 0.0,
            };
    }
    if (replyToMessageId != null) {
      json['reply_to'] = {
        '@type': 'messageReplyToMessage',
        'chat_id': replyToChatId,
        'message_id': replyToMessageId,
        // Non-nullable in TDLib's decoder even though it is meaningless for a
        // same-chat reply — a missing key throws "Null is not a subtype of int".
        'origin_send_date': 0,
      };
    }
    return td.Message.fromJson(json);
  }

  // ── Statistics ─────────────────────────────────────────────────────────────

  /// A `statisticalValue`, the shape every headline figure arrives in.
  static Map<String, dynamic> statisticalValueJson({
    required double value,
    double previousValue = 0,
    double growthRatePercentage = 0,
  }) => {
    '@type': 'statisticalValue',
    'value': value,
    'previous_value': previousValue,
    'growth_rate_percentage': growthRatePercentage,
  };

  /// A graph Telegram sent the data for.
  static Map<String, dynamic> graphDataJson(
    String jsonData, {
    String zoomToken = '',
  }) => {
    '@type': 'statisticalGraphData',
    'json_data': jsonData,
    'zoom_token': zoomToken,
  };

  /// A graph Telegram sent a token for instead — the common case, and the one
  /// the lazy loading in `StatSection` exists for.
  static Map<String, dynamic> graphAsyncJson(String token) => {
    '@type': 'statisticalGraphAsync',
    'token': token,
  };

  static Map<String, dynamic> graphErrorJson(String message) => {
    '@type': 'statisticalGraphError',
    'error_message': message,
  };

  /// The chart payload itself, as the string TDLib nests it as.
  static String chartJson({
    List<int> timestamps = const [1719792000000, 1719878400000],
    Map<String, List<num>> series = const {
      'y0': [10, 20],
    },
    Map<String, String> types = const {'y0': 'line'},
    Map<String, String> names = const {'y0': 'Members'},
    Map<String, String> colors = const {'y0': '#4BC7C1'},
    bool percentage = false,
    bool stacked = false,
  }) {
    return jsonEncode({
      'columns': [
        ['x', ...timestamps],
        for (final entry in series.entries) [entry.key, ...entry.value],
      ],
      'types': {'x': 'x', ...types},
      'names': names,
      'colors': colors,
      'percentage': percentage,
      'stacked': stacked,
    });
  }

  /// One row of `recent_interactions`.
  static Map<String, dynamic> interactionJson({
    required int messageId,
    int viewCount = 0,
    int forwardCount = 0,
    int reactionCount = 0,
    bool isStory = false,
  }) => {
    '@type': 'chatStatisticsInteractionInfo',
    'object_type': isStory
        ? {'@type': 'chatStatisticsObjectTypeStory', 'story_id': messageId}
        : {'@type': 'chatStatisticsObjectTypeMessage', 'message_id': messageId},
    'view_count': viewCount,
    'forward_count': forwardCount,
    'reaction_count': reactionCount,
  };

  /// A channel's statistics.
  ///
  /// Every graph defaults to an async token, because that is what TDLib
  /// actually sends; pass one in to test the resolved path.
  static td.ChatStatisticsChannel channelStatistics({
    int startDate = 1719792000,
    int endDate = 1727654400,
    Map<String, dynamic>? memberCount,
    Map<String, dynamic>? meanViewCount,
    Map<String, dynamic>? meanShareCount,
    Map<String, dynamic>? meanReactionCount,
    double enabledNotificationsPercentage = 42.5,
    Map<String, dynamic>? memberCountGraph,
    Map<String, dynamic>? messageInteractionGraph,
    List<Map<String, dynamic>> recentInteractions = const [],
  }) {
    final async = graphAsyncJson('token');
    final value = statisticalValueJson(value: 0);

    return td.ChatStatisticsChannel.fromJson({
      '@type': 'chatStatisticsChannel',
      'period': {
        '@type': 'dateRange',
        'start_date': startDate,
        'end_date': endDate,
      },
      'member_count': memberCount ?? value,
      'mean_message_view_count': meanViewCount ?? value,
      'mean_message_share_count': meanShareCount ?? value,
      'mean_message_reaction_count': meanReactionCount ?? value,
      'mean_story_view_count': value,
      'mean_story_share_count': value,
      'mean_story_reaction_count': value,
      'enabled_notifications_percentage': enabledNotificationsPercentage,
      'member_count_graph': memberCountGraph ?? async,
      'join_graph': async,
      'mute_graph': async,
      'view_count_by_hour_graph': async,
      'view_count_by_source_graph': async,
      'join_by_source_graph': async,
      'language_graph': async,
      'message_interaction_graph': messageInteractionGraph ?? async,
      'message_reaction_graph': async,
      'story_interaction_graph': async,
      'story_reaction_graph': async,
      'instant_view_interaction_graph': async,
      'recent_interactions': recentInteractions,
    });
  }

  /// A supergroup's statistics — the variant the channel screen must refuse.
  static td.ChatStatisticsSupergroup supergroupStatistics() {
    final async = graphAsyncJson('token');
    final value = statisticalValueJson(value: 0);

    return td.ChatStatisticsSupergroup.fromJson({
      '@type': 'chatStatisticsSupergroup',
      'period': {'@type': 'dateRange', 'start_date': 0, 'end_date': 1},
      'member_count': value,
      'message_count': value,
      'viewer_count': value,
      'sender_count': value,
      'member_count_graph': async,
      'join_graph': async,
      'join_by_source_graph': async,
      'language_graph': async,
      'message_content_graph': async,
      'action_graph': async,
      'day_graph': async,
      'week_graph': async,
      'top_senders': const [],
      'top_administrators': const [],
      'top_inviters': const [],
    });
  }
}
