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

  /// The one place the version is written.
  ///
  /// It reaches the drawer, the settings screen, and the name Telegram shows
  /// for this session under Settings → Devices. Keep it in step with
  /// `pubspec.yaml`; a test fails if the two drift.
  static const appVersion = '1.0.0';

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
  static const a11yVerified = 'Verified channel';
  static const a11yChannelPhotoTile = 'Photo — open the post it came from';
  static const a11yChannelVideoTile = 'Video — open the post it came from';
  static const a11yPinnedPost = 'Pinned post';
  static const a11yReactionsReadOnly = 'reactions';

  /// Shown on a photo tile when auto-download is off.
  static const mediaTapToLoad = 'Tap to load';

  static const settingsAutoDownloadImagesTitle = 'Auto-download photos';
  static const settingsAutoDownloadImagesBody =
      'Off: photos show their tiny built-in preview and load the full picture '
      'when you tap. Videos and files are already tap-to-load.';

  // ── Guest mode ─────────────────────────────────────────────────────────────
  static const guestBrowseAction = 'Browse without an account';
  static const guestBrowseSubtitle =
      'Read public channels straight from Telegram. No sign-in, and nothing '
      'is sent on your behalf.';
  static const guestBannerTitle = 'You are browsing as a guest';
  static const guestBannerBody =
      'Sign in to react, comment, bookmark and sync what you have read.';
  static const guestBannerAction = 'Sign in';
  static const guestSignInSheetTitle = 'Sign in to do that';
  static const guestSignInSheetBody =
      'Reacting, commenting and bookmarking all happen on a Telegram account. '
      'Guest mode only reads what a channel has made public.';
  static const guestSignInSheetDismiss = 'Keep browsing';

  static const guestChannelsTitle = 'Channels you follow here';
  static const guestEmptyTitle = 'Add a public channel';
  static const guestEmptyBody =
      'Enter a public channel username and gramX will read its posts straight '
      'from Telegram. Private channels need an account.';
  static const guestAddHint = 'durov';
  static const guestAddLabel = 'Public channel username';
  static const guestAddAction = 'Add channel';
  static const guestRemoveAction = 'Remove this channel';
  static const guestFeedEmptyTitle = 'Nothing here yet';
  static const guestFeedEmptyBody =
      'Add a public channel and its posts will appear here.';
  static const guestLeaveTitle = 'Leave guest mode?';
  static const guestLeaveBody =
      'Your channel list and the pictures cached for it will be deleted from '
      'this device. Signing in does not need them.';
  static const guestLeaveConfirm = 'Leave and sign in';

  static String guestRemoved(String username) => 'Removed @$username.';
  static String guestAdded(String title) => 'Added $title.';
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

  static const commentsHeading = 'Comments';
  static const commentsLoginPrompt = 'Log in to Telegram to post comments.';
  static const commentReplyingTo = 'Replying to ';

  static String commentReplyingToAuthor(String author) => 'Replying to @$author';

  // ── Post statistics ────────────────────────────────────────────────────────
  static const statReposts = 'Reposts';
  static const statLikes = 'Likes';
  static const statViews = 'Views';

  static String postError(Object error) => 'Error: $error';

  // ── Search ─────────────────────────────────────────────────────────────────
  static const searchHint = 'Search posts and channels';
  static const searchNoResults = 'No results found';
  static const searchClear = 'Clear search';
  static const searchFilterAll = 'All';
  static const searchFilterChannels = 'Channels';
  static const searchFilterPosts = 'Posts';
  static const searchExploreTitle = 'Explore';
  static const searchExploreBody = 'Subscribe to channels to discover posts.';
  static const searchRecentHeading = 'Recent from your channels';

  static String searchChannelsHeading(int count) => 'Channels ($count)';

  static String searchError(Object error) => 'Search failed: $error';

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
  static const channelLoadFailed = "Couldn't load this channel.";
  static const channelPostsFailed = "Couldn't load this channel's posts.";
  static const channelUnavailable = 'This channel is private or unavailable.';
  static const retry = 'Try again';

  static String subscriberCount(int count) =>
      count == 1 ? '1 subscriber' : '$count subscribers';

  /// Already-abbreviated count, for a row that has no room for the long form.
  static String subscriberCountShort(String formattedCount) =>
      '$formattedCount subscribers';

  static const channelsFilterAll = 'All';

  // ── Channel profile tabs ───────────────────────────────────────────────────
  static const channelTabPosts = 'Posts';
  static const channelTabMedia = 'Media';
  static const channelTabFiles = 'Files';
  static const channelTabLinks = 'Links';
  static const channelTabVoice = 'Voice';

  static const channelTabNoMedia = 'No photos or videos yet.';
  static const channelTabNoFiles = 'No files yet.';
  static const channelTabNoLinks = 'No links yet.';
  static const channelTabNoVoice = 'No voice or video messages yet.';
  static const channelTabFailed = "Couldn't load this tab.";

  static const channelFallbackTitle = 'Channel';
  static const channelPinnedLabel = 'Pinned';
  static const channelOpenPost = 'Open post';
  static const channelBannerLabel = 'Channel cover image';
  static const channelJoinAction = 'Join';
  static const channelJoinedAction = 'Joined';

  static String channelJoined(String title) => 'Joined $title';
  static String channelLeft(String title) => 'Left $title';

  // ── Muting ─────────────────────────────────────────────────────────────────
  static const muteSheetTitle = 'Mute this channel';
  static const muteSheetBody =
      'Its posts stay out of your feed until the mute lifts. Nothing is '
      'unsubscribed, and your Telegram is untouched.';
  static const muteOneHour = '1 hour';
  static const muteEightHours = '8 hours';
  static const muteTwoDays = '2 days';
  static const muteForever = 'Until I unmute';

  static String channelMutedFor(String duration) =>
      duration == muteForever ? 'Muted.' : 'Muted for $duration.';

  static String channelsMutedUntil(String when) => 'Muted until $when';

  static const channelsMutedLabel = 'Muted — hidden from your feed';
  static const channelsMutedIndefinitely = 'Muted — hidden until you unmute';
  static const channelsMuteAction = 'Mute this channel';
  static const channelsUnmuteAction = 'Unmute this channel';
  static const channelsNoMutedTitle = 'Nothing muted';
  static const channelsNoMutedBody =
      'Muted channels stay in this list so you can bring them back. Mute one '
      'from here or from its profile.';
  static const channelsAddBody =
      'Enter a public Telegram channel username (for example, durov). You will '
      'be subscribed to it.';
  static const channelsAddFieldLabel = 'Channel username';
  static const channelsAddFieldHint = 'durov';
  static const channelsAddConfirm = 'Add';
  static const channelsAddNotFound = "Couldn't find that channel.";
  static const channelsAddJoinFailed = "Couldn't subscribe to that channel.";

  static String channelsFilterMuted(int count) => 'Muted ($count)';

  static String channelsAdded(String title) => 'Subscribed to $title.';

  static String channelsError(Object error) => 'Error loading channels: $error';

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

  static String bookmarksError(Object error) => 'Error loading bookmarks: $error';

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

  static const settingsSupport = 'Support the Developer AKA RaGoose';
  static const settingsSupportBody = 'Support the developer and the project ❤️';
  static const settingsSource = 'Contribute on GitHub';
  static const settingsSourceBody = 'Help build the future of gramX 🚀';
  static const settingsLinkFailed = "Couldn't open that link.";

  static const settingsPrivacy = 'Privacy Policy';
  static const settingsPrivacyBody = 'What is stored, and what leaves your phone';
  static const settingsTerms = 'Terms of Service';
  static const settingsTermsBody = 'What this app is, and what it is not';
  static const settingsVersion = 'Version';

  // ── Legal ──────────────────────────────────────────────────────────────────
  static const legalNotFoundTitle = 'Not found';
  static const legalNotFoundBody = 'That document does not exist.';
  static const legalAgreementLead = 'By signing in you agree to the ';
  static const legalAgreementMiddle = ' and ';
  static const legalAgreementEnd = '.';

  static String legalLastUpdated(String date) => 'Last updated $date';
  static const settingsLogOut = 'Log out';
  static const settingsLogOutTitle = 'Log out of gramX?';
  static const settingsLogOutBody =
      'You will need to re-login to access your synced Telegram timeline and '
      'channels.';
  static const settingsCancel = 'Cancel';

  static String settingsStorageUsage(String size) => '$size of downloaded media';

  static String settingsStorageFreed(String size) =>
      'Freed $size of cached media.';

  // ── Drawer ─────────────────────────────────────────────────────────────────
  static const drawerProfile = 'My Profile';
  static const drawerBookmarks = 'Saved Messages & Bookmarks';
  static const drawerChannels = 'Subscribed Channels';
  static const drawerFolders = 'Folders';
  static const drawerSettings = 'Settings & Privacy';
  static const drawerChannelsCount = 'Channels';
  static const drawerFoldersCount = 'Folders';
  static const drawerAccountFallback = 'Telegram User';

  static String appVersionLabel([String version = appVersion]) =>
      'gramX v$version';

  // ── Profile ────────────────────────────────────────────────────────────────
  static const profileTitle = 'Profile';
  static const profileGuestName = 'Guest User';
  static const profileGuestHandle = '@guest';
  static const profileSectionDetails = 'ACCOUNT DETAILS';
  static const profilePhone = 'Phone number';
  static const profileTelegramId = 'Telegram ID';
  static const profileNotProvided = 'Not provided';
  static const profileStatus = 'Status';
  static const profileStatusOffline = 'Not logged in';
  static const profileLogIn = 'Log in with Telegram';
  static const profileCopied = 'Copied to clipboard.';
  static const profileOpenSettings = 'Settings and privacy';
  static const profileOpenSettingsBody =
      'Appearance, playback, storage and your account';

  static String profileError(Object error) => 'Error: $error';

  // ── Onboarding & auth ──────────────────────────────────────────────────────
  static const onboardingWelcome = 'Welcome to gramX';
  static const onboardingLoggedOutBody =
      'One timeline for the Telegram channels you follow. Log in with your '
      'Telegram account to view your subscribed channels and feeds.';
  static const onboardingLoggedInBody =
      "You haven't subscribed to any channels yet. Add public Telegram channels "
      'to build your custom feed.';
  static const onboardingLogIn = 'Log in with Telegram';
  static const authTagline =
      'Your Telegram channels, as one timeline.';
  static const authContinueWithPhone = 'Continue with Phone Number';
  static const authLogInWithQr = 'Log in via QR Code';
  static const authGeneratingQr = 'Generating QR…';
  static const authConnecting = 'Connecting to Telegram';
  static const authResetConnection = 'Reset Connection';
  static const authLogInPrompt = 'Log in to Telegram';
  static const authLogInBody = 'Sync your channels, folders, and timeline';

  static const replyUnavailable = 'Message unavailable';

  // ── Rich text ──────────────────────────────────────────────────────────────
  static const codeBlockLabel = 'Code';
  static const codeBlockCopy = 'Copy code';
  static const codeBlockCopied = 'Code copied to clipboard.';
  static const postShowMore = 'Show more';
  static const postShowLess = 'Show less';

  static String linkCouldNotOpen(String url) => 'Could not open link: $url';

  // ── Threads ────────────────────────────────────────────────────────────────
  static const threadHide = 'Hide earlier posts';

  static String threadShow(int count) => count == 1
      ? 'Show 1 earlier post in this thread'
      : 'Show $count earlier posts in this thread';

  // ── Video ──────────────────────────────────────────────────────────────────
  static const videoUnavailable = "This video isn't available.";
  static const videoPreparing = 'Preparing video…';

  static String videoDownloading(int percent) => 'Downloading… $percent%';

  static const videoPlay = 'Play';
  static const videoPause = 'Pause';
  static const videoMute = 'Mute';
  static const videoUnmute = 'Unmute';

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

  // ── Document & audio downloads ──────────────────────────────────────────
  static const documentDownloading = 'Downloading file…';
  static const documentOpenFailed = "Couldn't open this file";
  static const documentNoAppFound = 'No app found to open this file';
  static const audioDownloading = 'Downloading audio…';
}
