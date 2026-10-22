/// Trok's Telegram bots. gramX signs in to Trok through [trok], and a
/// mention of it calls Trok into a chat, where Trok's server writes the
/// answer. gramX writes and shows each of them as [shown].
abstract final class TrokBots {
  /// Trok's bot, for signing in and for mentions written in gramX.
  static const trok = 'trokkai';

  /// Every bot that has stood for Trok in a message, earlier ones included.
  static const all = {'trokkai', 'trokagent', 'tr0kbot'};

  /// How gramX writes and shows a mention of Trok.
  static const shown = '@Trok';

  /// Whether `@`[username] calls Trok.
  static bool calls(String username) =>
      all.contains(username.replaceFirst('@', '').toLowerCase());
}
