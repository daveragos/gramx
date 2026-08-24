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

  /// Whether the reader chose to browse without a Telegram account.
  ///
  /// Persisted here rather than held in memory because it decides whether the
  /// app shell is reachable at all: a guest who closes the app and reopens it
  /// must land back in their feed, not on the sign-in screen they deliberately
  /// walked past.
  final bool guestMode;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.autoPlay = AutoPlayPolicy.always,
    this.guestMode = false,
  });

  /// True when videos and GIFs should start on their own.
  bool get autoPlayEnabled => autoPlay == AutoPlayPolicy.always;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AutoPlayPolicy? autoPlay,
    bool? guestMode,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      autoPlay: autoPlay ?? this.autoPlay,
      guestMode: guestMode ?? this.guestMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'autoPlay': autoPlay.name,
        'guestMode': guestMode,
      };

  /// Tolerant by design: a settings file written by an older or newer build
  /// should cost the user their preference for one field, never the whole file.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: AppThemeMode.fromName(json['themeMode'] as String?),
      autoPlay: AutoPlayPolicy.fromName(json['autoPlay'] as String?),
      guestMode: json['guestMode'] as bool? ?? false,
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
      other.guestMode == guestMode;

  @override
  int get hashCode => Object.hash(themeMode, autoPlay, guestMode);

  @override
  String toString() => 'AppSettings(theme: ${themeMode.name}, '
      'autoPlay: ${autoPlay.name}, guest: $guestMode)';
}
