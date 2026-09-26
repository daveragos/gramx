///
/// Deliberately free of TDLib: the search filter each tab maps to lives in
/// `ChannelMediaRepository`, so the enum can be used from the widget layer
/// without dragging the client in behind it.
///
/// [posts] is the odd one out — it is the channel's history, served by the
/// existing `channelPostsProvider`, not by a search. Every other tab costs one
/// networked `SearchChatMessages` per page, which is why nothing is fetched
/// until the reader actually selects the tab.
enum ChannelTab {
  posts,
  media,
  files,
  links,
  voice;

  /// Whether this tab is served by the channel's plain history.
  bool get isHistory => this == ChannelTab.posts;

  /// How the tab's rows are drawn.
  ///
  /// Media is a grid and files are rows because that is the point of having
  /// the tab at all — a column of post cards is what the Posts tab already is.
  ChannelTabLayout get layout => switch (this) {
        ChannelTab.posts => ChannelTabLayout.cards,
        ChannelTab.media => ChannelTabLayout.grid,
        ChannelTab.files => ChannelTabLayout.fileRows,
        ChannelTab.links => ChannelTabLayout.cards,
        ChannelTab.voice => ChannelTabLayout.cards,
      };
}

enum ChannelTabLayout { cards, grid, fileRows }
