/// Conversions between TDLib's internal identifiers and the ones Telegram's
/// public surfaces (t.me links, the Bot API) use.
///
/// TDLib does not hand out the numbers you see in a t.me URL. Message ids are
/// shifted, and chat ids carry a type prefix. Anything that leaves the client
/// has to convert first — see `docs/TDLIB.md` → Quirks worth knowing.
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

  /// The supergroup id inside a chat id, or null if it isn't a supergroup chat.
  ///
  /// `-1001234567890` → `1234567890`. A positive id is already a supergroup id.
  static int? supergroupId(int chatId) {
    if (chatId > 0) return chatId;
    final text = chatId.toString();
    if (!text.startsWith(_supergroupChatPrefix)) return null;
    return int.tryParse(text.substring(_supergroupChatPrefix.length));
  }

  /// A shareable t.me link for a channel post.
  ///
  /// Public channels get `t.me/<username>/<id>`, which anyone can open. Private
  /// ones fall back to `t.me/c/<supergroupId>/<id>`, which only resolves for
  /// members — the best that exists for a private channel.
  ///
  /// Returns null when the chat id isn't a supergroup and there is no username,
  /// because no valid link exists for that case.
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
