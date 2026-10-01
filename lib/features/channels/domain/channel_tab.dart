/// The tabs on a channel's profile. [posts] is the channel's history; every
/// other tab costs a networked search per page, so it loads only once
/// selected.
enum ChannelTab {
  posts,
  media,
  files,
  links,
  voice;

  /// Whether this tab is served by the channel's plain history.
  bool get isHistory => this == ChannelTab.posts;

  /// How the tab's rows are drawn.
  ChannelTabLayout get layout => switch (this) {
    ChannelTab.posts => ChannelTabLayout.cards,
    ChannelTab.media => ChannelTabLayout.grid,
    ChannelTab.files => ChannelTabLayout.fileRows,
    ChannelTab.links => ChannelTabLayout.cards,
    ChannelTab.voice => ChannelTabLayout.cards,
  };
}

enum ChannelTabLayout { cards, grid, fileRows }
