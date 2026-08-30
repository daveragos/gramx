import 'dart:convert';

/// How videos and GIFs behave in the feed.
enum AutoPlayPolicy {
  /// Nothing starts on its own; tap to play.
  never,

  /// Media plays while it is on screen. GIFs are short and silent, so this is
  /// the default — it is what makes a feed of reaction GIFs read correctly.
  always;

  static AutoPlayPolicy fromName(String? name) => AutoPlayPolicy.values
      .firstWhere((v) => v.name == name, orElse: () => AutoPlayPolicy.always);
}

/// Whether photos fetch themselves, or wait to be asked.
///
/// Separate from [AutoPlayPolicy]: a GIF that plays on its own is a question
/// about motion, a photo that downloads on its own is a question about data.
/// Someone on a metered connection wants the second off and may not care about
/// the first.
enum AutoDownloadPolicy {
  /// Photos load when they scroll into view. The default — a feed of blurred
  /// placeholders is not a feed.
  always,

  /// Only the tiny embedded preview loads; the full photo waits for a tap.
  ///
  /// The preview is the minithumbnail Telegram ships inside the message
  /// itself, so it costs no request at all. That is what makes "off" show
  /// something rather than a grey box.
  never;

  static AutoDownloadPolicy fromName(String? name) =>
      AutoDownloadPolicy.values.firstWhere(
        (v) => v.name == name,
        orElse: () => AutoDownloadPolicy.always,
      );
}

enum AppThemeMode {
  light,
  dim,
  dark;

  static AppThemeMode fromName(String? name) => AppThemeMode.values
      .firstWhere((v) => v.name == name, orElse: () => AppThemeMode.dark);
}

/// Everything the settings screen can change, in one immutable value.
///
/// Kept as one object rather than a provider per toggle so persistence is a
/// single read and a single write, and so a new setting cannot be added without
/// also being saved.
class AppSettings {
  final AppThemeMode themeMode;
  final AutoPlayPolicy autoPlay;
  final AutoDownloadPolicy autoDownloadImages;

  /// Whether the reader chose to browse without a Telegram account.
  ///
  /// Persisted here rather than held in memory because it decides whether the
  /// app shell is reachable at all: a guest who closes the app and reopens it
  /// must land back in their feed, not on the sign-in screen they deliberately
  /// walked past.
  final bool guestMode;

  /// Whether gramX may put a notification on the screen.
  ///
  /// Defaults **off**, and that is deliberate: turning it on is also what asks
  /// the operating system for permission, and a permission dialog nobody asked
  /// for is the one every reader declines — after which the app has to send
  /// them to their system settings to undo it. Off until Settings is visited
  /// costs a reader who wants notifications one tap, once.
  final bool notificationsEnabled;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.autoPlay = AutoPlayPolicy.always,
    this.autoDownloadImages = AutoDownloadPolicy.always,
    this.guestMode = false,
    this.notificationsEnabled = false,
  });

  /// True when videos and GIFs should start on their own.
  bool get autoPlayEnabled => autoPlay == AutoPlayPolicy.always;

  /// True when a photo should fetch itself as it scrolls into view.
  bool get autoDownloadImagesEnabled =>
      autoDownloadImages == AutoDownloadPolicy.always;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AutoPlayPolicy? autoPlay,
    AutoDownloadPolicy? autoDownloadImages,
    bool? guestMode,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      autoPlay: autoPlay ?? this.autoPlay,
      autoDownloadImages: autoDownloadImages ?? this.autoDownloadImages,
      guestMode: guestMode ?? this.guestMode,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'autoPlay': autoPlay.name,
        'autoDownloadImages': autoDownloadImages.name,
        'guestMode': guestMode,
        'notificationsEnabled': notificationsEnabled,
      };

  /// Tolerant by design: a settings file written by an older or newer build
  /// should cost the user their preference for one field, never the whole file.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: AppThemeMode.fromName(json['themeMode'] as String?),
      autoPlay: AutoPlayPolicy.fromName(json['autoPlay'] as String?),
      autoDownloadImages:
          AutoDownloadPolicy.fromName(json['autoDownloadImages'] as String?),
      guestMode: json['guestMode'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
    );
  }

  static AppSettings decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) return const AppSettings();
    return AppSettings.fromJson(decoded);
  }

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.autoPlay == autoPlay &&
      other.autoDownloadImages == autoDownloadImages &&
      other.guestMode == guestMode;

  @override
  int get hashCode =>
      Object.hash(themeMode, autoPlay, autoDownloadImages, guestMode);

  @override
  String toString() => 'AppSettings(theme: ${themeMode.name}, '
      'autoPlay: ${autoPlay.name}, '
      'autoDownloadImages: ${autoDownloadImages.name}, guest: $guestMode)';
}
