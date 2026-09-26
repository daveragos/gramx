import 'package:gramx/features/activity/domain/activity_item.dart'
    show ActivityKind;
import 'package:gramx/features/compose/domain/poll_draft.dart'
    show PollDraft, PollDraftError;
import 'package:gramx/features/compose/presentation/post_progress_provider.dart'
    show PostSendStatus;

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

  /// A username as Telegram writes it, with the one `@` that marks it.
  ///
  /// Here rather than inlined at four call sites, because the prefix is a
  /// convention rather than part of the name — a locale that marks handles
  /// differently changes it once.
  static String handle(String username) => '@$username';

  /// The interpunct gramX separates inline facts with.
  ///
  /// gramX uses it between a handle and a subscriber count; it is one glyph in
  /// one place so the spacing cannot drift between them.
  static const inlineSeparator = ' · ';

  /// The same mark where the layout already supplies the spacing.
  static const inlineSeparatorBare = '·';

  /// The second of two back presses is the one that leaves. Said in the shell
  /// and on the sign-in screen, which are the two places back can exit from.
  static const pressBackAgainToExit = 'Press back again to exit';
  static const appName = 'gramX';

  /// The one place the version is written.
  ///
  /// It reaches the drawer, the settings screen, and the name Telegram shows
  /// for this session under Settings → Devices. Keep it in step with
  /// `pubspec.yaml`; a test fails if the two drift.
  static const appVersion = '1.0.0';

  /// The version alone, as the Settings row shows it. The drawer says
  /// [appVersionLabel] instead, which names the app as well.
  static const appVersionValue = 'v$appVersion';

  // ── Feed ───────────────────────────────────────────────────────────────────
  static String feedError(Object error) => 'Error: $error';

  /// How many people have answered a poll, already abbreviated by the caller.
  static String pollVoteCount(String formattedCount) => '$formattedCount votes';
  static String pollVoteFailed(Object error) => 'Failed to vote: $error';

  /// Sends a multiple-answer poll's selection. Single-answer polls have no
  /// such moment — the tap is the vote — so this appears on nothing else.
  static const pollVote = 'Vote';
  static const pollPoll = 'Poll';
  static const pollQuiz = 'Quiz';
  static const pollFinalResults = 'Final results';
  static const feedSyncingTitle = 'Syncing Telegram Feed';
  static const feedSyncingBody =
      'Fetching your subscribed channels and history from Telegram...';
  static const feedEmptyTitleAll = 'No posts yet';
  static const feedErrorTitle = 'Something went wrong';
  static const feedCaughtUpTitle = "You're all caught up";
  static const feedCaughtUpBody =
      'Posts you have read are cleared on refresh. New ones will appear here.';
  static const feedScrollToTop = 'Top';
  static const feedPressBackAgain = pressBackAgainToExit;
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

  /// A counted action, read out as one phrase — "12 replies" rather than a
  /// number and a word arriving as two separate labels.
  static String a11yCountedAction(int count, String action) =>
      '$count $action';
  static const postLinkCopied = 'Post link copied to clipboard.';
  static const postNotLinkable = "This post can't be linked to.";
  static const postNotFound = 'Post not found';
  static const postUnreachableBody =
      "This post is in a channel you're not in, or it has been deleted. "
      'It may still open in Telegram.';
  static const postOpenInTelegram = 'Open in Telegram';
  static const postMenuCopyLink = 'Copy link';
  static const postMenuTooltip = 'More';
  static String postMenuMute(String channel) => 'Mute $channel';
  static String postMenuUnmute(String channel) => 'Unmute $channel';
  static String postMenuLeave(String channel) => 'Leave $channel';

  /// Content nothing here can draw, whichever way the reader got to it.
  ///
  /// Signed in, TDLib itself says it cannot represent the message — a message
  /// type newer than the TDLib this build links against. As a guest, the
  /// `t.me` preview page says the same thing about itself. Either way Telegram
  /// can still show it, which is what the button under this offers; the
  /// sentence says what happened, not what to do, because the button already
  /// says that.
  static const postUnsupported =
      "gramX can't show this post — Telegram itself still can.";
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
      'Off: photos load only when you tap them.';

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
  static const guestAddHint = 'ragoose_dumps';
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
  static const guestUndo = 'Undo';

  static const guestAddTooltip = 'Add a public channel';
  static const guestPasteTooltip = 'Paste a link or username';
  static const guestOpenChannel = 'Open this channel';
  static const guestNotAUsername = 'That is not a Telegram channel username.';
  static String guestAlreadyAdded(String username) =>
      'You have already added @$username.';
  static String guestChannelNotPublic(String username) =>
      '@$username is private, or does not exist. Guest mode can only read '
      'public channels.';
  static String guestChannelUnreadable(String username) =>
      'Could not read @$username.';

  static const guestRetryAction = 'Retry';
  static String guestChannelsFailed(int count) => count == 1
      ? 'One channel could not be read.'
      : '$count channels could not be read.';
  static const guestFeedFailedTitle = 'Could not reach Telegram';
  static String guestFeedLoading(int done, int total) =>
      'Reading channel $done of $total…';
  static const guestFeedEnd = 'You have reached the end of these channels.';
  static const a11yOpenMenu = 'Open navigation menu';
  static const a11yScrollToTop = 'Scroll to top';

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
  static const commentHint = 'Add a comment…';
  static const commentReplyHint = 'Post your reply…';

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

  static const searchWhoToFollow = 'Channels you might like';
  static const searchWhoToFollowBody =
      'Suggested by Telegram, from the channels you already read.';
  static const searchFollowAction = 'Follow';

  // ── Channels ───────────────────────────────────────────────────────────────
  static const channelAddFieldLabel = 'Channel Username';
  static const channelAddCancel = 'Cancel';
  static const channelAddSubmit = 'Add';
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

  // Leaving is the one membership change that cannot be undone with the same
  // tap: rejoining a private channel needs an invite the reader may not have.
  // Joining is asymmetric — it is instantly reversible — so only this side is
  // confirmed.
  static const channelLeaveConfirmTitle = 'Leave this channel?';
  static String channelLeaveConfirmBody(String title) =>
      'Its posts stop arriving in your feed, and you leave $title on every '
      'device signed in to your Telegram. A private channel needs a fresh '
      'invite to get back into.';
  static const channelLeaveConfirmAction = 'Leave';
  static const channelLeaveFailed = 'Could not leave the channel.';
  static const channelLeaveCancelAction = 'Stay';

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
  static const channelsMutedIndefinitely = 'Muted';
  static const channelsMuteAction = 'Mute this channel';
  static const channelsUnmuteAction = 'Unmute this channel';
  static const channelsNoMutedTitle = 'Nothing muted';
  static const channelsNoMutedBody =
      'Muted channels stay in this list so you can bring them back. Mute one '
      'from here or from its profile.';
  static const channelsAddBody =
      'Enter a public Telegram channel username (for example, ragoose_dumps). You will '
      'be subscribed to it.';
  static const channelsAddFieldLabel = 'Channel username';
  static const channelsAddFieldHint = 'ragoose_dumps';
  static const channelsAddConfirm = 'Add';
  static const channelsAddNotFound = "Couldn't find that channel.";
  static const channelsAddJoinFailed = "Couldn't subscribe to that channel.";

  static String channelsFilterMuted(int count) => 'Muted ($count)';

  static String channelsAdded(String title) => 'Subscribed to $title.';

  static String channelsError(Object error) => 'Error loading channels: $error';

  // ── Folders ────────────────────────────────────────────────────────────────
  static String foldersError(Object error) => 'Error loading folders: $error';
  static const foldersTitle = 'Folders';
  static const foldersEmptyTitle = 'No folders found';
  static const foldersEmptyBody =
      'Your Telegram chat folders will sync and show up here once you subscribe '
      'to channels and group them.';
  static const foldersCounting = 'Counting…';
  static const foldersCountUnavailable = 'Count unavailable';

  static String folderChannelCount(int count) =>
      count == 1 ? '1 channel' : '$count channels';

  // ── Activity ───────────────────────────────────────────────────────────────
  static const activityTitle = 'Activity';
  static const activityTabAll = 'All';
  static const activityTabMentions = 'Mentions';
  static const activityTabReactions = 'Reactions';
  static const homeNewPostsSemantics = 'Home, new posts waiting';
  static const drawerActivity = 'Activity';
  static const activityEmptyTitle = 'Nothing has happened';
  static const activityEmptyBody =
      'Mentions, replies and reactions to your messages will appear here.';
  static const activityErrorTitle = 'Could not load your activity';
  static String activityError(Object error) => '$error';

  /// The one-line headline on a row.
  ///
  /// Reads as the sentence it produces — "Ada reacted ❤️ in Flutter Devs" —
  /// which is why it takes named parts rather than a format string: a locale
  /// that puts the place first only has to change this.
  static String activityHeadline({
    required ActivityKind kind,
    required String who,
    required String where,
    String? emoji,
  }) {
    final place = where.isEmpty ? '' : ' in $where';
    return switch (kind) {
      ActivityKind.mention => '$who mentioned you$place',
      ActivityKind.reply => '$who replied to you$place',
      ActivityKind.reaction =>
        emoji == null || emoji.isEmpty
            ? '$who reacted to your message$place'
            : '$who reacted $emoji$place',
    };
  }

  /// The mark beside a row carries its meaning by shape and colour, neither of
  /// which is read out. This is the word for it.
  static String activityKindLabel(ActivityKind kind) => switch (kind) {
    ActivityKind.mention => 'Mention',
    ActivityKind.reply => 'Reply',
    ActivityKind.reaction => 'Reaction',
  };

  /// The bell's badge, capped the way every unread count is.
  static String activityBadge(int count) => count > 99 ? '99+' : '$count';

  static String a11yActivity(int count) => count == 0
      ? 'Activity'
      : 'Activity, $count new';

  // ── Bookmarks ──────────────────────────────────────────────────────────────
  static const bookmarksTitle = 'Bookmarks';
  static const bookmarksEmptyTitle = 'Save posts for later';
  static const bookmarksEmptyBody =
      "Don't let the good ones fly away! Bookmark posts to easily find them "
      'again in the future.';

  static String bookmarksError(Object error) =>
      'Error loading bookmarks: $error';

  static const bookmarksRestore = 'Restore from Saved Messages';
  static const bookmarksRestoreBody =
      'gramX keeps a copy of every bookmark in your Telegram Saved Messages, '
      'so they survive a reinstall. This reads them back.';

  static String bookmarksRestored(int count) => switch (count) {
    0 => 'Nothing to restore — every saved bookmark is already here.',
    1 => 'Restored 1 bookmark.',
    _ => 'Restored $count bookmarks.',
  };

  // ── Settings ───────────────────────────────────────────────────────────────
  static String settingsAccountError(Object error) =>
      'Error loading account: $error';
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
  static const settingsThemeSystem = 'Use device setting';
  static const settingsThemeSystemBody =
      'Light or Lights out, whichever your phone is using';

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
  static const settingsPrivacyBody =
      'What is stored, and what leaves your phone';
  static const settingsTerms = 'Terms of Service';
  static const settingsTermsBody = 'What this app is, and what it is not';
  static const settingsVersion = 'Version';

  // ── Notifications ──────────────────────────────────────────────────────────
  static const settingsSectionNotifications = 'Notifications';
  static const notificationsEnableTitle = 'Notify me';
  static const notificationsEnableBody =
      'Mentions, replies and messages, decided by Telegram — so a chat you '
      'muted there stays quiet here.';
  static const notificationsDeniedTitle = 'Notifications are blocked';
  static const notificationsDeniedBody =
      'Your device refused the request. Turn gramX on in your system '
      'notification settings, then try again.';

  /// The name of the Android channel, which the reader sees in their own
  /// system settings — so it says what it carries, not what the code calls it.
  static const notificationsChannelName = 'Messages and mentions';
  static const notificationsChannelBody =
      'New messages, mentions and replies from Telegram.';

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

  static String settingsStorageUsage(String size) =>
      '$size of downloaded media';

  static String settingsStorageFreed(String size) =>
      'Freed $size of cached media.';

  // ── Drawer ─────────────────────────────────────────────────────────────────
  static const drawerProfile = 'My Profile';
  // Two different things that used to share one row. The label promised Saved
  // Messages — Telegram's notes-to-self chat — and delivered the bookmark
  // list, which is this app's own. They are separate entries now.
  static const drawerBookmarks = 'Bookmarks';
  static const drawerSavedMessages = 'Saved Messages';

  /// The chat with yourself, wherever it is listed or opened.
  static const savedMessagesTitle = drawerSavedMessages;
  static const savedMessagesUnavailable =
      "Couldn't open Saved Messages. Try again in a moment.";
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
  static const profileTabBookmarks = 'Bookmarks';
  static const profileTabChannels = 'Channels';
  static const profileMoreTooltip = 'More';
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
  /// Both the shell and the sign-in screen arm the same two-press exit, so
  /// they say it with the same sentence rather than two that drift apart.
  static const authPressBackAgain = pressBackAgainToExit;
  static const authUsePhoneInstead = 'Use a phone number instead';
  static const authCountrySearchLabel = 'Search Country';
  static const authCountrySearchHint =
      'Start typing country name or code...';
  static const authPasswordHint = 'Cloud password';

  /// The dots standing in for the login code, one per digit Telegram sends.
  static const authCodeHint = '••••••';

  /// An example number in the shape the reader's own country writes them.
  static String authPhoneHint(String dialCode) => '$dialCode 123 456 7890';
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

  /// quotes it. The card is a link, and a screen reader needs to hear whose
  /// post it leads to before hearing the words in it.
  static String quotedPostBy(String name) => 'Quoted post by $name';

  /// Read out for the passage a reply singled out, which stands above the
  /// reply rather than inside it. Named apart from [quotedPostBy] because it
  /// is a fragment of a post, not a post — and it leads to the message the
  /// fragment came out of.
  static String quotedPassageBy(String name) => 'Quoted passage from $name';

  /// The same, for a passage whose origin channel Telegram would not name — a
  /// private one, or one nothing has cached. Saying whose it is would mean
  /// guessing, and the guess is always the channel doing the quoting.
  static const quotedPassageUnattributed = 'Quoted passage';

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
  static const spoilerLabel = 'Spoiler';
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
  static const mediaLocation = 'Location';

  static String mediaPosition(String kind, int index, int total) =>
      '$kind $index of $total';

  // ── Document & audio downloads ──────────────────────────────────────────
  static const documentOpenFailed = "Couldn't open this file";
  static const documentNoAppFound = 'No app found to open this file';

  // Both rows show their own progress ring now, so neither announces the start
  // of a download in a snackbar. A toast that says "downloading…" and is then
  // never followed up is the least useful shape this could take: it covers the
  // very control that would have shown how far along the file is.
  static const documentFallbackName = 'Document file';
  static const documentTapToDownload = 'Tap to download';
  static const documentDownloaded = 'Downloaded';
  static const documentDownloadingLabel = 'Downloading';

  static String downloadPercent(int percent) => '$percent%';

  static const audioPlay = 'Play';
  static const audioPause = 'Pause';
  static const audioDownload = 'Download';
  static const audioSeek = 'Seek';
  static const audioKindVoice = 'Voice';
  static const audioKindAudio = 'Audio';

  static const shareNowhereToPost =
      'There is nowhere to post this. gramX can only write to channels and '
      'chats your account can post in.';

  // ── Composing ──────────────────────────────────────────────────────────────
  static const composeHint = "What's happening?";
  static const composePost = 'Post';
  static const composeClose = 'Close';

  static const composeTargetTitle = 'Post to';
  static const composeTargetSearchHint = 'Search destinations';
  static const composeTargetsEmpty = 'Nowhere to post';
  static const composeTargetsEmptyBody =
      "You can post to channels you run, groups you can write in, and your own "
      'Saved Messages. None of those are available on this account yet.';
  static const composeTargetNoMatch = 'No destination matches that';
  static const composeSavedMessages = 'Saved Messages';

  static const composeGroupChannels = 'Channels';
  static const composeGroupGroups = 'Groups';
  static const composeGroupSaved = 'Yourself';
  static const composeGroupDirect = 'Direct messages';

  static const composeAddPhoto = 'Add photo';
  static const composeAddVideo = 'Add video';
  static const composeAddFile = 'Add file';
  static const composeAddVideoNote = 'Record a video message';
  static const composeAddLocation = 'Send my location';
  static const composeAddContact = 'Share a contact';
  static const composeAddSticker = 'Add sticker';
  static const composeAddGif = 'Add GIF';

  static const composeStickersTab = 'Stickers';
  static const composeGifsTab = 'GIFs';
  static const composeStickersFavourites = 'Favourites';
  static const composeStickersRecent = 'Recently used';
  static const composeNoStickers = 'No stickers here yet';
  static const composeNoGifs =
      'No saved GIFs. Save one in Telegram and it will show up here.';

  /// A sticker has no words of its own; the emoji it stands for is the only
  /// name Telegram gives it.
  static String a11ySticker(String emoji) =>
      emoji.isEmpty ? 'Sticker' : 'Sticker $emoji';

  /// Why a sticker and written text cannot go out together.
  static const composeStickerTakesNoCaption =
      'Telegram sends a sticker on its own — it cannot carry a caption. Remove '
      'the sticker or clear the text.';

  static const composeRemoveSticker = 'Remove sticker';
  static const composeRemoveGif = 'Remove GIF';
  static const composeRemoveAttachment = 'Remove attachment';
  static const composePickFailed = "Couldn't open the gallery.";

  static const composeDiscardTitle = 'Discard post?';
  static const composeDiscardBody = "This draft won't be saved.";
  static const composeDiscardConfirm = 'Discard';
  static const composeDiscardCancel = 'Keep writing';

  static const a11yCompose = 'Write a post';
  static const a11yComposeCharacters = 'Characters remaining';
  static const a11yComposeChangeTarget = 'Change where this posts';

  static String composePostingTo(String title) => 'Posting to $title';

  static String composeSent(String title) => 'Posted to $title.';

  static String composeFailed(String title) => "Couldn't post to $title.";

  /// Shown when the writer tries to attach an eleventh file. Telegram's own
  /// album limit, not this app's.
  static String composeAttachmentLimit(int max) => max == 1
      ? 'Only one file can be attached.'
      : 'Up to $max files per post.';

  // Three ways Telegram refuses a photo. It answers all three with the same
  // unhelpful error, so each is named here instead.
  static String composePhotoTooLarge(int maxMegabytes) =>
      'Telegram only takes photos up to $maxMegabytes MB.';

  static String composePhotoTooManyPixels(int maxTotal) =>
      "That photo is too big for Telegram — its width and height can't add up "
      'to more than $maxTotal pixels.';

  static String composePhotoTooWide(int maxRatio) =>
      'That photo is too long and thin for Telegram — one side can be at most '
      '$maxRatio times the other.';

  /// Why the character allowance shrank the moment a photo was attached.
  static String composeCaptionLimit(int limit) =>
      'A post with media is captioned, so it is capped at $limit characters.';

  /// What the bar over the timeline is saying, for a screen reader.
  ///
  /// The bar itself is three pixels of colour: it carries its meaning by
  /// position and motion, neither of which is read out. This is the sentence
  /// that says the same thing.
  static String composeProgressLabel(PostSendStatus status, String target) =>
      switch (status) {
        PostSendStatus.uploading => 'Posting to $target…',
        PostSendStatus.sent => 'Posted to $target.',
        PostSendStatus.failed => 'Could not post to $target.',
      };

  // ── Messages ───────────────────────────────────────────────────────────────
  static const messagesTitle = 'Chat';
  static const messagesTab = 'Messages';
  static const messagesSearchHint = 'Search';
  static const messagesEmptyTitle = 'No conversations yet';
  static const messagesEmptyBody =
      'Messages you exchange on Telegram appear here.';
  static const messagesEmptyFilteredTitle = 'Nothing here';
  static const messagesEmptyFilteredBody =
      'No conversation matches this filter.';
  static const messagesNoSearchResults = 'No conversation matches that.';
  static const messagesFilterTooltip = 'Filter conversations';
  static const messagesMarkAllRead = 'Mark all as read';
  static const messagesSettings = 'Settings';
  static const messagesNewChat = 'New message';
  static const messagesNewChatHint = 'Search for a person or group';
  static const messagesGuestTitle = 'Messages need an account';
  static const messagesGuestBody =
      'Guest mode reads public channels through their web preview. There is no '
      'account behind it to send or receive a message with.';
  static const messagesGuestAction = 'Sign in to Telegram';
  static const messagesDraftPrefix = 'Draft';
  static const messagesYouPrefix = 'You';
  static const messagesMarkedUnread = 'Marked unread';
  static const messagesMuted = 'Muted';
  static const messagesRequestBadge = 'Request';
  static const messagesBotBadge = 'bot';
  static const messagesPinned = 'Pinned';
  static const messagesPin = 'Pin to top';
  static const messagesUnpin = 'Unpin';
  static const messagesMute = 'Mute';
  static const messagesUnmute = 'Unmute';
  static const messagesMarkRead = 'Mark as read';
  static const messagesMarkUnread = 'Mark as unread';
  static const messagesPinFailed =
      "Telegram wouldn't pin that — you may have pinned as many as it allows.";
  static const messagesStartOne = 'Start a conversation';

  // Taking a conversation off the list. A group is left; a one-to-one chat,
  // which there is no leaving, is deleted.
  static const messagesDeleteChat = 'Delete chat';
  static const messagesLeaveGroup = 'Leave group';
  static String messagesDeleteChatTitle(String title) =>
      'Delete the chat with $title?';
  static const messagesDeleteChatBody =
      'Its messages are removed from this account. This cannot be undone.';
  static String messagesDeleteForBoth(String title) =>
      'Delete for me and $title';
  static String messagesLeaveGroupTitle(String title) => 'Leave $title?';
  static const messagesLeaveGroupBody =
      "You'll stop getting its messages. Rejoining a private group needs a "
      'new invite.';
  static const messagesDeleteFailed = "Telegram wouldn't delete that chat.";
  static const messagesLeaveFailed = "Telegram wouldn't let you leave.";

  // Blocking, from a profile or from a message sent by a stranger.
  static const userBlock = 'Block';
  static const userUnblock = 'Unblock';
  static String userBlockTitle(String name) => 'Block $name?';
  static const userBlockBody =
      "They won't be able to message you or call you. They are not told.";
  static const userBlocked = 'Blocked.';
  static const userUnblocked = 'Unblocked.';
  static const userBlockFailed = "Telegram wouldn't change that.";

  // The bar across a chat started by somebody the reader does not know.
  static const requestBarText = "You don't have this person in your contacts.";
  static const requestBarDismiss = 'Dismiss';

  // ── Polls somebody is writing ──────────────────────────────────────────────
  static const pollComposeTitle = 'New poll';
  static const pollComposeCreate = 'Create';
  static const pollComposeQuestionHint = 'Ask a question';
  static const pollComposeQuestionLabel = 'Question';
  static const pollComposeOptionsLabel = 'Options';
  static const pollComposeAddOption = 'Add an option';
  static const pollComposeRemoveOption = 'Remove this option';
  static const pollComposeAnonymous = 'Anonymous votes';
  static const pollComposeAnonymousBody = "Voters' names stay hidden.";
  static const pollComposeMultiple = 'Multiple answers';
  static const pollComposeMultipleBody = 'Let people pick more than one.';
  static const pollComposeQuizMode = 'Quiz mode';
  static const pollComposeQuizModeBody =
      'One answer is right, and voters are told which.';
  static const pollComposeMarkCorrect = 'Mark as the right answer';
  static const pollComposeDiscardTitle = 'Discard poll?';
  static const pollComposeDiscardBody = "This poll won't be saved.";
  static const pollComposeSendFailed = "Telegram wouldn't take that poll.";
  static const pollComposeUnavailable = 'Polls';
  static String pollComposeOptionHint(int number) => 'Option $number';

  /// Why the Create button is off. One sentence per rule the draft breaks,
  /// shown for the one it is currently breaking — a poll refused by Telegram
  /// comes back as a flat error that names no field at all.
  static String pollComposeProblem(PollDraftError error) => switch (error) {
    PollDraftError.questionEmpty => 'A poll needs a question.',
    PollDraftError.questionTooLong =>
      'That question is longer than Telegram allows '
          '(${PollDraft.maxQuestionLength} characters).',
    PollDraftError.tooFewOptions =>
      'A poll needs at least ${PollDraft.minOptions} options.',
    PollDraftError.optionTooLong =>
      'An option can be at most ${PollDraft.maxOptionLength} characters.',
    PollDraftError.duplicateOptions => 'Two options say the same thing.',
    PollDraftError.quizNeedsAnswer => 'Mark which answer is the right one.',
  };

  // ── Voice messages ─────────────────────────────────────────────────────────
  static const voiceRecord = 'Record a voice message';
  static const voiceCancel = 'Discard this recording';
  static const voiceNoMicrophone =
      'gramX needs the microphone to record a voice message.';
  static const voiceUnavailable = "This device wouldn't start recording.";
  static const voiceTooShort = 'That was too short to send.';

  static String voiceRecordingLabel(int seconds) =>
      'Recording, $seconds seconds so far';

  // ── Round video messages ───────────────────────────────────────────────────
  static const videoNoteTitle = 'Video message';
  static const videoNoteHint = 'Tap the button to record. Tap again to send.';
  static const videoNoteNoCamera =
      'gramX needs the camera to record a video message.';
  static const videoNoteUnavailable = "This device wouldn't start the camera.";
  static const videoNoteRecord = 'Start recording';
  static const videoNoteStop = 'Stop and send';
  static const videoNoteFlip = 'Switch camera';
  static const videoNoteClose = 'Close';

  static String videoNoteRemaining(int seconds) => '${seconds}s left';

  // ── Locations and contacts ─────────────────────────────────────────────────
  static const locationSendFailed = "Couldn't send your location.";
  static const locationNoPermission =
      'gramX needs your location to send it. You can allow it in Settings.';
  static const locationUnavailable =
      "This device couldn't work out where it is.";
  static const locationOpenInMaps = 'Open in maps';
  static const locationLabel = 'Location';
  static const contactSendFailed = "Couldn't send that contact.";
  static const contactPickTitle = 'Share a contact';
  static const contactPickHint = 'Search your Telegram contacts';
  static const contactPickEmpty = 'No contacts to share';
  static const contactPickNoMatch = 'No contact matches that';
  static const contactMessage = 'Contact';
  static const placeLiveLocation = 'Live location';
  static const placeOpenFailed = "Couldn't open a maps app.";

  /// A place with no name and no address: the numbers are the only thing that
  /// says which place it is.
  static String placeCoordinates(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  // ── End-to-end chats ───────────────────────────────────────────────────────
  static const secretChatBadge = 'Secret';
  static const secretChatStart = 'Start a secret chat';
  static const secretChatStartBody =
      'Messages are encrypted end to end, live only on these two devices, and '
      'are not in your Telegram cloud.';
  static const secretChatStartConfirm = 'Start';
  static const secretChatFailed = "Telegram wouldn't start a secret chat.";
  static const secretChatPending =
      'Waiting for them to come online. Nothing can be sent until their device '
      'finishes setting up the encryption.';
  static const secretChatPendingShort = 'Waiting for them to come online';
  static const secretChatClose = 'End secret chat';
  static const secretChatCloseTitle = 'End this secret chat?';
  static const secretChatCloseBody =
      "It ends for both of you, and it can't be reopened. The messages in it "
      'are deleted from both devices.';
  static const secretChatCloseConfirm = 'End it';
  static const secretChatCloseFailed = "Couldn't end that chat.";
  static const secretChatLockLabel = 'End-to-end encrypted';

  // ── Scheduled messages ─────────────────────────────────────────────────────
  static const scheduleTitle = 'Send later';
  static const scheduleWhenOnline = 'When they come online';
  static const scheduleWhenOnlineBody =
      'Telegram holds it until they next open the app.';
  static const schedulePickDate = 'Pick a date and time';
  static const scheduleTooltip = 'Send later';
  static const chatSendOrSchedule = 'Send. Hold to send later.';
  static const scheduleScreenTitle = 'Scheduled';
  static const scheduleMenu = 'Scheduled messages';
  static const scheduleEmpty = 'Nothing is scheduled here';
  static const scheduleSendNow = 'Send now';
  static const scheduleDelete = 'Delete';
  static const scheduleFailed = "Telegram wouldn't schedule that.";
  static const scheduleInvalid =
      'Pick a time at least a minute from now, and within a year.';
  static const scheduleSent = 'Sent.';
  static const scheduleQueued = 'Scheduled.';
  static const scheduleRescheduleFailed = "Couldn't change that.";
  static const scheduleWhenOnlineRow = 'When they come online';

  static String scheduleIn(Duration offset) {
    if (offset.inHours < 24) {
      return offset.inHours == 1 ? 'In 1 hour' : 'In ${offset.inHours} hours';
    }
    final days = offset.inDays;
    return days == 1 ? 'In 1 day' : 'In $days days';
  }

  static String scheduledFor(String when) => 'Sends $when';

  // ── Selecting several messages ─────────────────────────────────────────────
  static const chatActionSelect = 'Select';
  static const chatSelectCancel = 'Stop selecting';
  static const chatForwardFailedPlain = "Couldn't forward those.";

  static String chatSelectedCount(int count) =>
      count == 1 ? '1 selected' : '$count selected';

  static String chatSelectLimit(int max) =>
      'Telegram takes at most $max messages at a time.';

  static String chatForwardedCount(int count) =>
      count == 1 ? 'Forwarded.' : 'Forwarded $count messages.';

  static String chatDeleteCountTitle(int count) =>
      count == 1 ? chatDeleteTitle : 'Delete $count messages?';

  // ── The chat's own timer ───────────────────────────────────────────────────
  static const autoDeleteTitle = 'Auto-delete messages';
  static const autoDeleteBody =
      'Applies to everything either of you sends from now on. Both of you are '
      'told when it changes.';
  static const autoDeleteMenu = 'Auto-delete messages';
  static const chatMoreTooltip = 'More';
  static const autoDeleteOff = 'Off';
  static const autoDeleteFailed = "Telegram wouldn't change that timer.";

  /// One auto-delete length, in the words Telegram's own clients use.
  ///
  /// Falls back to a day count for a timer set elsewhere to a length gramX does
  /// not offer — the sheet shows it rather than pretending nothing is set.
  static String autoDeleteChoice(int seconds) => switch (seconds) {
    0 => autoDeleteOff,
    86400 => 'After 1 day',
    604800 => 'After 1 week',
    2678400 => 'After 1 month',
    _ when seconds >= 86400 => 'After ${seconds ~/ 86400} days',
    _ when seconds >= 3600 => 'After ${seconds ~/ 3600} hours',
    _ => 'After $seconds seconds',
  };

  static String autoDeleteSet(int seconds) => seconds == 0
      ? 'Messages will no longer auto-delete.'
      : 'Messages will delete ${autoDeleteChoice(seconds).toLowerCase()}.';

  // ── Pinning one message ────────────────────────────────────────────────────
  static const chatActionPin = 'Pin';
  static const chatActionUnpin = 'Unpin';
  static const chatPinTitle = 'Pin this message?';
  static const chatPinBody =
      'Everybody in this chat will see it at the top. They are not notified.';
  static const chatPinConfirm = 'Pin';
  static const chatPinned = 'Pinned.';
  static const chatUnpinned = 'Unpinned.';
  static const chatPinFailed = "Telegram wouldn't pin that.";
  static const chatUnpinFailed = "Telegram wouldn't unpin that.";

  // ── Media that disappears ──────────────────────────────────────────────────
  static const selfDestructTitle = 'Disappearing media';
  static const selfDestructOff = 'Stays in the chat';
  static const selfDestructViewOnce = 'View once';
  static const selfDestructViewOnceBody = 'Gone as soon as they close it.';
  static const selfDestructOption = 'Disappearing';
  static const selfDestructSpoiler = 'Hide behind a spoiler';
  static const selfDestructSpoilerOn = 'Spoiler on';
  static const selfDestructPrivateOnly =
      'Telegram only takes disappearing media in a one-to-one chat.';

  static String selfDestructAfter(int seconds) =>
      seconds >= 60 ? 'After 1 minute' : 'After $seconds seconds';

  /// The strip under an attachment, saying what will happen to it.
  static String selfDestructSummary(int seconds, bool viewOnce) => viewOnce
      ? selfDestructViewOnce
      : (seconds >= 60 ? '1 min' : '$seconds s');

  /// The cover over a disappearing photo somebody has been sent.
  static const secretMediaTapToView = 'Tap to view';
  static const secretMediaPhoto = 'Photo';
  static const secretMediaVideo = 'Video';
  static const secretMediaOutgoing = 'They have not opened it yet';
  static const secretMediaOpenFailed = "Couldn't open that.";
  static const secretMediaClose = 'Close';

  /// What tapping the cover is about to do, said before it is done. Opening is
  /// irreversible — Telegram tells the sender, and the media is then gone.
  static const secretMediaOnceWarning =
      'You can only see this once. It disappears when you close it.';

  static String secretMediaTimerWarning(int seconds) =>
      'You get $seconds seconds with this, then it disappears.';

  static String secretMediaCountdown(int seconds) => '${seconds}s';
  static const messagesAllReadDone = 'Everything marked as read.';

  /// The count on the Messages tab. Conversations, not messages: "3" should
  /// mean three people are waiting, which is a number somebody can act on.
  static String messagesUnreadBadge(int count) =>
      count > 99 ? '99+' : count.toString();

  static String messagesUnreadSemantics(int count) => count == 1
      ? 'Messages, 1 unread conversation'
      : 'Messages, $count unread conversations';

  // ── Service lines: what happened to a chat, centred between the bubbles ────
  // Every one of these used to be drawn as an empty line, so a public group —
  // mostly joins — read as a column of blank gaps under date headers.
  static String serviceJoined(String who) => '$who joined the group';
  static String serviceAdded(String who, String whom) => '$who added $whom';
  static String serviceJoinedByLink(String who) =>
      '$who joined the group via invite link';
  static String serviceAccepted(String who) =>
      '$who was accepted into the group';
  static String serviceLeft(String who) => '$who left the group';
  static String serviceRemoved(String who, String whom) => '$who removed $whom';
  static String servicePinned(String who) => '$who pinned a message';
  static String serviceRenamed(String who, String title) =>
      '$who changed the group name to "$title"';
  static String servicePhotoChanged(String who) =>
      '$who changed the group photo';
  static String servicePhotoRemoved(String who) =>
      '$who removed the group photo';
  static String serviceCreated(String who, String title) =>
      '$who created the group "$title"';
  static const serviceUpgraded = 'The group was upgraded to a supergroup';
  static String serviceScreenshot(String who) => '$who took a screenshot';
  static String serviceAutoDelete(String who, int seconds) => seconds == 0
      ? '$who turned off auto-delete'
      : '$who set messages to delete '
            '${autoDeleteChoice(seconds).toLowerCase()}';
  static String serviceJoinedTelegram(String who) => '$who joined Telegram';
  static const serviceVideoChatStarted = 'Video chat started';
  static const serviceVideoChatEnded = 'Video chat ended';
  static String serviceTopicCreated(String name) => 'Topic "$name" created';
  static String serviceBoosted(String who) => '$who boosted the group';

  /// Whoever did it, when Telegram does not say or the cache does not know.
  static const serviceSomeone = 'Someone';

  // ── A conversation ─────────────────────────────────────────────────────────
  static const chatComposerHint = 'Message';
  static const chatSend = 'Send';
  static const chatAttach = 'Attach a photo or video';
  static const chatLoadingHistory = 'Loading messages';
  static const chatEmptyTitle = 'No messages yet';
  static const chatEmptyBody = 'Say something to start this conversation.';
  static const chatHistoryFailed = "Couldn't load this conversation.";
  static const chatSendFailed = "Couldn't send that. Tap to try again.";
  static const chatRetry = 'Retry';
  static const chatEdited = 'edited';
  static const chatReplyingTo = 'Replying to';

  /// being answered, above the answer. Telegram's bordered quote block is the
  /// other convention, and it turns every reply in a conversation into a card
  /// inside a card.
  static String chatReplyingToName(String name) => 'Replying to $name';

  /// The "↱ Forwarded from Ada" line above a forwarded message.
  static String chatForwardedFrom(String name) => 'Forwarded from $name';
  static const chatCancelReply = 'Cancel reply';
  static const chatDeletedMessage = 'This message was deleted.';
  static const chatOpenInTelegram = 'Open in Telegram';
  static const chatUnsupported = "gramX can't show this message yet.";
  static const chatScrollToBottom = 'Jump to the latest message';
  static const chatOnline = 'online';

  // Message long-press menu.
  static const chatActionReply = 'Reply';
  static const chatActionForward = 'Forward';

  // Handing a file to another app on the device.
  static const openWith = 'Open with…';
  static const openWithNotReady = "That file hasn't finished downloading yet.";

  /// A mention Telegram cannot resolve — a private account, or a name that has
  /// since changed.
  static String chatMentionUnknown(String username) =>
      "Telegram doesn't know @$username.";
  static const chatForwarded = 'Forwarded.';
  static const chatForwardFailed = "Telegram wouldn't forward that.";

  /// A reply, pin or search hit that Telegram no longer has. Anything it
  /// still has is jumped to, however far back — see
  /// `ConversationNotifier.reveal`.
  static const chatMessageTooFarBack =
      "Couldn't find that message. It may have been deleted.";
  static const chatActionCopy = 'Copy text';
  static const chatActionEdit = 'Edit';
  static const chatActionDelete = 'Delete';
  static const chatActionDeleteForMe = 'Delete for me';
  static const chatActionDeleteForEveryone = 'Delete for everyone';
  static const chatActionReact = 'React';
  static const chatCopied = 'Copied.';
  static const chatDeleteTitle = 'Delete message?';
  static const chatDeleteBody =
      "This can't be undone. Choose who it disappears for.";
  static const chatCancel = 'Cancel';
  static const chatEditTitle = 'Edit message';
  static const commentEditTitle = 'Edit comment';
  static const postEditTitle = 'Edit post';
  static const postMenuEdit = 'Edit post';
  static const chatSave = 'Save';
  static const chatEditFailed = "Telegram wouldn't take that edit.";
  static const chatEditSaved = 'Saved.';

  /// The composer's stickers-and-GIFs button, and the picker it opens.
  static const chatStickers = 'Stickers and GIFs';

  /// The one button the composer's tools fold into while somebody is typing,
  /// so the field gets the width back. Tapping it unfolds them.
  static const chatComposerMoreTools = 'More';
  static const chatDeleteFailed = "Telegram wouldn't delete that.";

  /// The date band between two days of messages. Today and yesterday get their
  /// names because a date nobody has to decode reads faster.
  /// The band a chat opens on when messages were waiting. Everything below it
  /// is new since the reader was last here.
  static const chatUnreadBand = 'Unread messages';

  static const chatToday = 'Today';
  static const chatYesterday = 'Yesterday';

  /// What somebody in the chat is doing right now. In a group the name is
  /// carried, because "typing" alone in a room of eight says nothing.
  static String chatTyping(String action, {String? name}) =>
      name == null ? '$action…' : '$name is $action…';

  /// Presence, in Telegram's own hedged words. It refuses to give a time for a
  /// contact who hides theirs, and inventing one here would be a lie about
  /// somebody's privacy setting.
  static const chatLastSeenRecently = 'last seen recently';
  static const chatLastSeenWeek = 'last seen within a week';
  static const chatLastSeenMonth = 'last seen within a month';
  static const chatLastSeenOffline = 'offline';

  static String chatMembers(int count) =>
      count == 1 ? '1 member' : '$count members';

  // What somebody is doing, for the typing line. Verb phrases, so they read
  // after a name in a group ("Ada is recording audio…") and alone in a private
  // chat ("recording audio…").
  static const chatActionTyping = 'typing';
  static const chatActionRecordingVideo = 'recording video';
  static const chatActionSendingVideo = 'sending a video';
  static const chatActionRecordingAudio = 'recording audio';
  static const chatActionSendingAudio = 'sending audio';
  static const chatActionSendingPhoto = 'sending a photo';
  static const chatActionSendingFile = 'sending a file';
  static const chatActionRecordingVideoMessage = 'recording a video message';
  static const chatActionSendingVideoMessage = 'sending a video message';
  static const chatActionChoosingSticker = 'choosing a sticker';
  static const chatActionChoosingLocation = 'choosing a location';
  static const chatActionChoosingContact = 'choosing a contact';
  static const chatActionWatchingAnimation = 'watching an animation';
  static const chatActionPlayingGame = 'playing a game';

  // Delivery state, for screen readers. The ticks are the visual form and
  // convey state by shape alone, which is exactly the case the accessibility
  // rule in docs/CONVENTIONS.md names.
  static const chatSearchTooltip = 'Search this conversation';
  static const chatSearchClose = 'Close search';
  static const chatSearchHint = 'Search messages';
  static const chatSearchPrompt = 'Type to search this conversation.';
  static const chatSearchFailed = 'Could not search this conversation.';
  static String chatSearchNoResults(String query) => 'No messages match "$query".';

  static const chatPinnedMessage = 'Pinned message';
  static const chatPinnedNoText = 'Pinned';

  // ── Peeking, and who somebody speaks for ────────────────────────────────
  static String chatPeekSemantics(String title) =>
      'Peek into the conversation with $title';
  static String chatAffiliation(String channel) => 'Runs the channel $channel';

  /// When the cache has the channel's id but not yet its name — see
  /// `ChatSummary.affiliatedChannelId` for why that is a normal state.
  static const chatAffiliationUnnamed = 'Runs a channel';

  static const chatPeekTitle = 'Peek';
  static const chatPeekHint =
      'Read-only. Nothing here is marked as read, and nobody is told you '
      'looked.';
  static const chatPeekOpen = 'Open chat';
  static const chatPeekEmpty = 'Nothing to look at yet.';
  static const chatPeekFailed = "Couldn't load this conversation.";

  // ── A person's profile ─────────────────────────────────────────────────────
  static const profileUserTitle = 'Profile';
  static const profileUserMissing = "Telegram doesn't know this account.";
  static const profileUserDeleted = 'This account was deleted.';
  static const profileMessageAction = 'Message';
  static const profileBotBadge = 'Bot';
  static const profilePremiumBadge = 'Premium';
  static const profileContactBadge = 'In your contacts';
  static const profileBioHeading = 'Bio';
  static const profilePhoneHeading = 'Phone';
  static const profileUsernameHeading = 'Username';
  static const profileChannelHeading = 'Runs';
  static const profileOpenChannel = 'Open channel';
  static const profileChannelUnnamed = 'A channel';

  static String profileGroupsInCommon(int count) =>
      count == 1 ? '1 group in common' : '$count groups in common';

  // ── Analytics ──────────────────────────────────────────────────────────────
  static const statsTitle = 'Analytics';
  static const statsTabOverview = 'Overview';
  static const statsTabAudience = 'Audience';
  static const statsTabContent = 'Content';
  static const statsUnavailable =
      "Telegram doesn't have analytics for this channel yet.";
  static const statsLoadFailed = "Couldn't load analytics.";
  static const statsGraphUnavailable = 'This chart is unavailable.';
  static const statsGraphEmpty = 'Not enough data for this chart yet.';
  static const statsAccountOverview = 'Account overview';

  /// The window Telegram's figures describe, e.g. `Jun 7 – Sep 7`.
  static String statsPeriod(String start, String end) => '$start – $end';

  /// A figure that is itself a percentage, e.g. notifications enabled.
  static String statsPercent(String value) => '$value%';

  /// The change against the previous period, without its arrow — the arrow is
  /// an icon, because a glyph in the string cannot be coloured or labelled.
  static String statsGrowth(String percent) => '$percent%';

  // Figure tiles.
  static const statsFollowers = 'Followers';
  static const statsNotifications = 'Notifications enabled';
  static const statsViewsPerPost = 'Views per post';
  static const statsSharesPerPost = 'Shares per post';
  static const statsReactionsPerPost = 'Reactions per post';

  // Chart titles.
  static const statsGraphGrowth = 'Followers over time';
  static const statsGraphJoins = 'Joined and left';
  static const statsGraphNotifications = 'Notifications';
  static const statsGraphViewsByHour = 'Active times';
  static const statsGraphViewsBySource = 'Views by source';
  static const statsGraphNewFollowersBySource = 'New followers by source';
  static const statsGraphLanguages = 'Languages';
  static const statsGraphInteractions = 'Views and shares per post';
  static const statsGraphReactions = 'Reactions per post';
  static const statsGraphInstantViews = 'Instant View opens';

  // The Content tab, and one post's own screen.
  static const statsRecentPosts = 'Recent posts';
  static const statsContentEmpty = 'No posts in this period.';
  static const statsPostFallback = 'Post';
  static const statsPostTitle = 'Post analytics';
  static const statsPostUnavailable =
      "Telegram doesn't have analytics for this post.";
  static const statsPostInteractions = 'Views and shares';
  static const statsPostReactions = 'Reactions';
  static const statsPublicShares = 'Shared by';
  static const statsPublicSharesEmpty =
      'Nobody has shared this to a public channel yet.';

  /// Takes the already-abbreviated count, the way every other count-bearing
  /// string here does — the formatting is `TimeUtils.formatCount`'s job.
  static String statsSharedViews(String count) => '$count views';

  // Spoken labels. Every figure on this screen is a number next to a word, and
  // a screen reader needs them read as one thing rather than as two.
  /// A count-bearing noun, said the way [a11yViews] is — "12 shares".
  static const a11yShares = 'shares';
  static const a11yChannelAnalytics = 'Channel analytics';
  static const a11yPostAnalytics = 'Post analytics';
  static const a11yStatsRising = 'up';
  static const a11yStatsFalling = 'down';

  static String a11yStatFigure(String label, String value) => '$label: $value';

  static String a11yStatChange(String direction, String percent) =>
      '$direction $percent% on the previous period';

  static String a11yStatChart(String title) => '$title chart';

  static const chatStateSending = 'Sending';
  static const chatStateSent = 'Sent';
  static const chatStateRead = 'Read';
  static const chatStateFailed = 'Failed to send';
}
