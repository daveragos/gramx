/// The filters in the chat list's header dropdown.
///
/// [bots] is kept apart from [direct] because bot traffic is most of a
/// typical account's private chats.
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
