/// The filters in the chat list's header dropdown.
///
/// directly; the fifth does not, and that is the one deliberate divergence:
///
/// * **Unread** — an unread count, or a chat marked unread by hand.
/// * **Direct** — private chats with people, and Saved Messages.
/// * **Groups** — basic groups and non-broadcast supergroups.
/// * **Bots** — where Requests used to be. Telegram has no message-request
///   inbox, so Requests had to be *inferred* from the report/add/block bar it
///   raises over a chat from a non-contact — the only filter in the menu whose
///   meaning was invented rather than found. Bots are a thing Telegram
///   genuinely models, and separating them is the more useful cut anyway: bot
///   traffic is the bulk of most Telegram accounts' private chats, and leaving
///   it mixed into Direct buries the people in it.
enum ChatFilter {
  all('All'),
  unread('Unread'),
  direct('Direct'),
  groups('Groups'),
  bots('Bots');

  const ChatFilter(this.label);

  /// The word shown in the header pill and the menu row.
  final String label;
}
