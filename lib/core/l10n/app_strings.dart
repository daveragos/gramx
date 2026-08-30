import 'package:gramx/core/diagnostics/error_log.dart' show ErrorSource;
import 'package:gramx/features/activity/domain/activity_item.dart'
    show ActivityKind;
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
  static const channelsMutedIndefinitely = 'Muted — hidden until you unmute';
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

  // ── Diagnostics ────────────────────────────────────────────────────────────
  static const diagnosticsTitle = 'Diagnostics';
  static const settingsDiagnostics = 'Diagnostics';
  static const settingsDiagnosticsBody =
      'What went wrong, and when. Nothing here is sent anywhere.';
  static const diagnosticsBody =
      'Errors gramX caught, newest first. They stay on this device — there is '
      'no reporting service — and phone numbers, file paths and keys are '
      'removed before anything is written down, so this is safe to share when '
      'somebody asks what happened.';
  static const diagnosticsEmptyTitle = 'Nothing has gone wrong';
  static const diagnosticsEmptyBody =
      'Errors gramX catches will be listed here.';
  static const diagnosticsCopy = 'Copy the whole log';
  static const diagnosticsCopied = 'Diagnostics copied to clipboard.';
  static const diagnosticsClear = 'Delete the log';

  /// Where an error came from, said the way a reader would say it.
  static String diagnosticsSource(ErrorSource source) => switch (source) {
    ErrorSource.widget => 'Drawing the screen',
    ErrorSource.platform => 'The device',
    ErrorSource.zone => 'Background work',
    ErrorSource.reported => 'gramX',
  };

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
  static const messagesAllReadDone = 'Everything marked as read.';

  /// The count on the Messages tab. Conversations, not messages: "3" should
  /// mean three people are waiting, which is a number somebody can act on.
  static String messagesUnreadBadge(int count) =>
      count > 99 ? '99+' : count.toString();

  static String messagesUnreadSemantics(int count) => count == 1
      ? 'Messages, 1 unread conversation'
      : 'Messages, $count unread conversations';

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
  static const chatReplyNotLoaded =
      "That message isn't loaded yet — scroll up to find it.";
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
  static const chatSave = 'Save';
  static const chatEditFailed = "Telegram wouldn't take that edit.";
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

  static const chatStateSending = 'Sending';
  static const chatStateSent = 'Sent';
  static const chatStateRead = 'Read';
  static const chatStateFailed = 'Failed to send';
}
