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
  static td.Chat chat({
    required int id,
    String title = 'Test Channel',
    bool isChannel = true,
    int mainOrder = 0,
    int unreadCount = 0,
    Map<String, dynamic>? lastMessage,
    List<Map<String, dynamic>>? positions,
  }) {
    return td.Chat.fromJson(<String, dynamic>{
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
      'permissions': _permissions,
      'last_message': lastMessage,
      'positions': positions ??
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
    });
  }

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

  static td.ChatPosition position({
    required int order,
    bool archive = false,
  }) {
    return td.ChatPosition.fromJson(
      archive ? archiveListPosition(order: order) : mainListPosition(order: order),
    );
  }

  /// A plain text message. [id] is the raw TDLib id (already shifted).
  static Map<String, dynamic> textMessageJson({
    required int id,
    required int chatId,
    String text = 'hello',
    int date = 1700000000,
  }) =>
      {
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

  static td.Message textMessage({
    required int id,
    required int chatId,
    String text = 'hello',
    int date = 1700000000,
  }) =>
      td.Message.fromJson(
        textMessageJson(id: id, chatId: chatId, text: text, date: date),
      );

  static td.UpdateNewChat newChat(td.Chat chat) =>
      td.UpdateNewChat(chat: chat);

  static td.UpdateChatLastMessage lastMessage({
    required int chatId,
    td.Message? message,
    int mainOrder = 0,
  }) =>
      td.UpdateChatLastMessage(
        chatId: chatId,
        lastMessage: message,
        positions: mainOrder == 0
            ? const []
            : [td.ChatPosition.fromJson(mainListPosition(order: mainOrder))],
      );
}
