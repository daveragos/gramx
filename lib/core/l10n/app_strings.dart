/// Every user-facing string in the app, in one place.
///
/// This is the groundwork for translation, not translation itself. The point is
/// that adding locales later means changing this file's internals, rather than
/// hunting hundreds of literals spread across widgets — which is the expensive
/// version of the same task.
///
/// Rules:
/// * No user-facing text as a literal inside a widget. If it appears on screen,
///   it belongs here.
/// * Anything with a count takes a parameter and picks its own plural, so a
///   locale with different plural rules has one place to change.
/// * Names are grouped by feature, then read like the sentence they produce.
///
/// When real translation is wanted, replace the bodies with lookups from
/// `flutter_localizations` / generated ARB accessors. Call sites don't change.
abstract class AppStrings {
  // ── App ────────────────────────────────────────────────────────────────────
  static const appName = 'gramX';

  // ── Feed ───────────────────────────────────────────────────────────────────
  static const feedSyncingTitle = 'Syncing Telegram Feed';
  static const feedSyncingBody =
      'Fetching your subscribed channels and history from Telegram...';
  static const feedEmptyTitleAll = 'No posts yet';
  static const feedErrorTitle = 'Something went wrong';
  static const feedCaughtUpTitle = "You're all caught up";
  static const feedCaughtUpBody =
      'Posts you have read are cleared on refresh. New ones will appear here.';
  static const feedScrollToTop = 'Top';
  static const feedPressBackAgain = 'Press back again to exit';
  static const feedCommentsDisabled = 'Comments are disabled for this channel.';
  static const feedOriginalChannelUnavailable =
      'Original channel is unavailable';

  static String feedEmptyTitle(String folder) => 'No posts in $folder';

  static String feedPrivateChannel(String title) =>
      'Channel "$title" is private or unavailable';

  /// The "N new posts" pill.
  static String newPostsPill(int count) =>
      count == 1 ? '1 new post' : '$count new posts';

  // ── Post actions ───────────────────────────────────────────────────────────
  static const postLinkCopied = 'Post link copied to clipboard.';
  static const postNotLinkable = "This post can't be linked to.";
  static const postNotFound = 'Post not found';
  static const postUnreachableBody =
      "This post is in a channel you're not in, or it has been deleted. "
      'It may still open in Telegram.';
  static const postOpenInTelegram = 'Open in Telegram';
  static const postCannotOpenTelegram = "Couldn't open Telegram.";
  static const postTitle = 'Post';

  static const a11yReply = 'Reply';
  static const a11yBookmarkAdd = 'Bookmark post';
  static const a11yBookmarkRemove = 'Remove bookmark';
  static const a11yCopyLink = 'Copy link to post';
  static const a11yReact = 'React to this post';
  static const a11yUnread = 'Unread';
  static const a11yOpenMenu = 'Open navigation menu';
  static const a11yScrollToTop = 'Scroll to top';
  static const a11ySearch = 'Search';

  static String a11yReplyWithCount(int count) =>
      count == 0 ? a11yReply : 'Reply, $count comments';

  static String a11yCurrentReaction(String emoji) =>
      'Your reaction $emoji. Double tap to remove, long press to change';

  // ── Forwarding ─────────────────────────────────────────────────────────────
  static const forwardTitle = 'Forward to';
  static const forwardSearchHint = 'Search chats';
  static const forwardNoChats = 'No chats to forward to';
  static const a11yForward = 'Forward post';
  static const a11yViews = 'views';

  static String forwardFailed(String chatTitle) =>
      "Couldn't forward to $chatTitle.";

  static String forwardSent(String chatTitle) => 'Forwarded to $chatTitle.';

  // ── Comments ───────────────────────────────────────────────────────────────
  static const commentPosted = 'Comment posted!';
  static const commentEmpty = 'No comments yet';

  static String commentFailed(Object error) => 'Failed to post comment: $error';

  // ── Search ─────────────────────────────────────────────────────────────────
  static const searchHint = 'Search posts and channels';
  static const searchNoResults = 'No results found';

  // ── Channels ───────────────────────────────────────────────────────────────
  static const channelsTitle = 'Channels';
  static const channelsEmptyTitle = 'No channels yet';
  static const channelsEmptyBody =
      'Add public channels or log in to sync channels you already subscribe to.';
  static const channelsAddPublic = 'Add Public Channel';
  static const channelHiddenFromFeed =
      'Hidden from feed. Posts from this channel are now hidden from your feed.';
  static const channelVisibleInFeed =
      'Visible in feed. Posts from this channel will appear in your feed.';
  static const channelNoPosts = 'No posts found in this channel.';

  static String subscriberCount(int count) =>
      count == 1 ? '1 subscriber' : '$count subscribers';

  // ── Folders ────────────────────────────────────────────────────────────────
  static const foldersTitle = 'Folders';
  static const foldersEmptyTitle = 'No folders found';
  static const foldersEmptyBody =
      'Your Telegram chat folders will sync and show up here once you subscribe '
      'to channels and group them.';
  static const foldersCounting = 'Counting…';
  static const foldersCountUnavailable = 'Count unavailable';

  static String folderChannelCount(int count) =>
      count == 1 ? '1 channel' : '$count channels';

  // ── Bookmarks ──────────────────────────────────────────────────────────────
  static const bookmarksTitle = 'Bookmarks';
  static const bookmarksEmptyTitle = 'Save posts for later';
  static const bookmarksEmptyBody =
      "Don't let the good ones fly away! Bookmark posts to easily find them "
      'again in the future.';

  // ── Settings ───────────────────────────────────────────────────────────────
  static const settingsTitle = 'Settings and privacy';
  static const settingsSectionAccount = 'YOUR ACCOUNT';
  static const settingsSectionDisplay = 'DISPLAY AND SOUND';
  static const settingsSectionPreferences = 'PREFERENCES';
  static const settingsSectionData = 'DATA AND STORAGE';
  static const settingsSectionAbout = 'ABOUT & SUPPORT';

  static const settingsAccountInfo = 'Account Information';
  static const settingsAccountInfoBody =
      'See your Telegram account details, ID, and phone number';
  static const settingsDarkModeLabel = 'Dark mode appearance';
  static const settingsThemeLight = 'Light';
  static const settingsThemeDim = 'Dim';
  static const settingsThemeDark = 'Lights out';

  static const settingsAutoPlayTitle = 'Auto-play videos and GIFs';
  static const settingsAutoPlayBody = 'Play silently while they are on screen';

  static const settingsStorageTitle = 'Media Storage & Cache';
  static const settingsStorageChecking = 'Checking…';
  static const settingsStorageFallback = 'Downloaded photos, video and files';
  static const settingsStorageNone = 'No cached media';
  static const settingsStorageClear = 'Clear';
  static const settingsStorageNothingToClear = 'Nothing to clear.';

  static const settingsVersion = 'Version';
  static const settingsLogOut = 'Log out';
  static const settingsLogOutTitle = 'Log out of gramX?';
  static const settingsLogOutBody =
      'You will need to re-login to access your synced Telegram timeline and '
      'channels.';
  static const settingsCancel = 'Cancel';

  static String settingsStorageUsage(String size) => '$size of downloaded media';

  static String settingsStorageFreed(String size) =>
      'Freed $size of cached media.';

  // ── Onboarding & auth ──────────────────────────────────────────────────────
  static const onboardingWelcome = 'Welcome to gramX';
  static const onboardingLoggedOutBody =
      'One timeline for the Telegram channels you follow. Log in with your '
      'Telegram account to view your subscribed channels and feeds.';
  static const onboardingLoggedInBody =
      "You haven't subscribed to any channels yet. Add public Telegram channels "
      'to build your custom feed.';
  static const onboardingLogIn = 'Log in with Telegram';
  static const authLogInPrompt = 'Log in to Telegram';
  static const authLogInBody = 'Sync your channels, folders, and timeline';

  // ── Video ──────────────────────────────────────────────────────────────────
  static const videoUnavailable = "This video isn't available.";
  static const videoPreparing = 'Preparing video…';

  static String videoDownloading(int percent) => 'Downloading… $percent%';

  // ── Spoilers ───────────────────────────────────────────────────────────────
  static const spoilerHidden = 'Hidden by a spoiler';
  static const spoilerTapToReveal = 'Tap to reveal';

  // ── Media ──────────────────────────────────────────────────────────────────
  static const mediaPhoto = 'Photo';
  static const mediaVideo = 'Video';
  static const mediaGif = 'GIF';
  static const mediaSticker = 'Sticker';
  static const mediaDocument = 'Document';
  static const mediaAudio = 'Audio track';
  static const mediaVoice = 'Voice message';

  static String mediaPosition(String kind, int index, int total) =>
      '$kind $index of $total';
}
