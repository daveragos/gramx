/// Conversions between TDLib's identifiers and the public ones used in t.me
/// links and the Bot API. TDLib message ids are shifted and chat ids carry a
/// type prefix.
abstract class TelegramIds {
  /// TDLib multiplies server message ids by 2^20 so it can address parts of a
  /// message (scheduled copies, album members) in the low bits.
  static const int messageIdShift = 20;

  /// Prefix TDLib puts in front of a supergroup id to make a chat id.
  static const String _supergroupChatPrefix = '-100';

  /// The message number Telegram shows in a link, e.g. the `42` in
  /// `t.me/channel/42`.
  static int serverMessageId(int tdlibMessageId) =>
      tdlibMessageId >> messageIdShift;

  /// The supergroup id inside a chat id (`-1001234567890` to `1234567890`), or
  /// null if it isn't a supergroup chat. A positive id is returned as is.
  static int? supergroupId(int chatId) {
    if (chatId > 0) return chatId;
    final text = chatId.toString();
    if (!text.startsWith(_supergroupChatPrefix)) return null;
    return int.tryParse(text.substring(_supergroupChatPrefix.length));
  }

  /// A shareable t.me link for a channel post: `t.me/<username>/<id>` for a
  /// public channel, or `t.me/c/<supergroupId>/<id>` (members only) for a
  /// private one. Null when neither applies.
  static String? postLink({
    required int chatId,
    required int messageId,
    String? username,
  }) {
    final id = serverMessageId(messageId);
    if (id <= 0) return null;

    final handle = username?.trim().replaceAll('@', '');
    if (handle != null && handle.isNotEmpty) {
      return 'https://t.me/$handle/$id';
    }

    final group = supergroupId(chatId);
    if (group == null) return null;
    return 'https://t.me/c/$group/$id';
  }
}
