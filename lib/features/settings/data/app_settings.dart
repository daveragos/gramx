import 'dart:convert';

/// How videos and GIFs behave in the feed.
enum AutoPlayPolicy {
  /// Nothing starts on its own; tap to play.
  never,

  /// Media plays while it is on screen. The default.
  always;

  static AutoPlayPolicy fromName(String? name) => AutoPlayPolicy.values
      .firstWhere((v) => v.name == name, orElse: () => AutoPlayPolicy.always);
}

/// Whether photos download on their own or wait for a tap. Separate from
/// [AutoPlayPolicy] because this one is about data use, not motion.
enum AutoDownloadPolicy {
  /// Photos load when they scroll into view. The default.
  always,

  /// Only the minithumbnail embedded in the message shows (it costs no
  /// request); the full photo waits for a tap.
  never;

  static AutoDownloadPolicy fromName(String? name) =>
      AutoDownloadPolicy.values.firstWhere(
        (v) => v.name == name,
        orElse: () => AutoDownloadPolicy.always,
      );
}

/// The app theme. [system] follows the device between [light] and [dark];
/// [dim] is only ever chosen by hand.
enum AppThemeMode {
  light,
  dim,
  dark,
  system;

  /// Whether the device decides between light and dark.
  bool get followsDevice => this == AppThemeMode.system;

  static AppThemeMode fromName(String? name) => AppThemeMode.values.firstWhere(
    (v) => v.name == name,
    orElse: () => AppThemeMode.dark,
  );
}

/// Everything the settings screen can change, in one immutable value, so
/// persistence is a single read and write.
class AppSettings {
  final AppThemeMode themeMode;
  final AutoPlayPolicy autoPlay;
  final AutoDownloadPolicy autoDownloadImages;

  /// Whether the user chose to browse without a Telegram account. Persisted
  /// so a guest reopening the app lands in the feed, not on sign-in.
  final bool guestMode;

  /// Whether gramX may show notifications. Off by default, so the Android
  /// permission is only requested when the user turns it on.
  final bool notificationsEnabled;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.autoPlay = AutoPlayPolicy.always,
    this.autoDownloadImages = AutoDownloadPolicy.always,
    this.guestMode = false,
    this.notificationsEnabled = false,
  });

  bool get autoPlayEnabled => autoPlay == AutoPlayPolicy.always;

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
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'autoPlay': autoPlay.name,
    'autoDownloadImages': autoDownloadImages.name,
    'guestMode': guestMode,
    'notificationsEnabled': notificationsEnabled,
  };

  /// Missing fields and unknown names fall back to defaults, so a file from
  /// an older or newer build keeps its other settings.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: AppThemeMode.fromName(json['themeMode'] as String?),
      autoPlay: AutoPlayPolicy.fromName(json['autoPlay'] as String?),
      autoDownloadImages: AutoDownloadPolicy.fromName(
        json['autoDownloadImages'] as String?,
      ),
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
      other.guestMode == guestMode &&
      other.notificationsEnabled == notificationsEnabled;

  @override
  int get hashCode => Object.hash(
    themeMode,
    autoPlay,
    autoDownloadImages,
    guestMode,
    notificationsEnabled,
  );

  @override
  String toString() =>
      'AppSettings(theme: ${themeMode.name}, '
      'autoPlay: ${autoPlay.name}, '
      'autoDownloadImages: ${autoDownloadImages.name}, guest: $guestMode)';
}
