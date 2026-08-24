import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:gramx/features/settings/data/app_settings.dart';

/// Reads and writes [AppSettings] as a JSON file in app documents.
///
/// A file rather than a key-value store because settings are one small object
/// that is always read and written together, and it matches how hidden channels
/// are already persisted.
class SettingsStore {
  static const String fileName = 'settings.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  /// Returns defaults if nothing is saved, or if the file is unreadable — a
  /// corrupt settings file should never stop the app from starting.
  Future<AppSettings> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const AppSettings();
      return AppSettings.decode(await file.readAsString());
    } catch (e) {
      debugPrint('[Settings] Could not read settings, using defaults: $e');
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    try {
      final file = await _file();
      await file.writeAsString(settings.encode());
    } catch (e) {
      debugPrint('[Settings] Could not save settings: $e');
    }
  }
}

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

/// The live settings, restored from disk on start and saved on every change.
///
/// Starts from the defaults and swaps in the saved values once the read
/// completes, so the first frame never waits on disk.
class SettingsNotifier extends Notifier<AppSettings> {
  bool _loaded = false;

  @override
  AppSettings build() {
    unawaited(_restore());
    return const AppSettings();
  }

  Future<void> _restore() async {
    final saved = await ref.read(settingsStoreProvider).load();
    _loaded = true;
    if (saved != state) state = saved;
  }

  void _update(AppSettings next) {
    if (next == state) return;
    state = next;
    unawaited(ref.read(settingsStoreProvider).save(next));
  }

  /// True once the saved settings have been read.
  ///
  /// Lets callers avoid writing a default over a value still being loaded.
  bool get isLoaded => _loaded;

  void setThemeMode(AppThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  void setAutoPlay(AutoPlayPolicy policy) =>
      _update(state.copyWith(autoPlay: policy));

  void toggleAutoPlay(bool enabled) => setAutoPlay(
      enabled ? AutoPlayPolicy.always : AutoPlayPolicy.never);

  void setAutoDownloadImages(AutoDownloadPolicy policy) =>
      _update(state.copyWith(autoDownloadImages: policy));

  void toggleAutoDownloadImages(bool enabled) => setAutoDownloadImages(
      enabled ? AutoDownloadPolicy.always : AutoDownloadPolicy.never);

  /// Enters or leaves browse-without-an-account.
  ///
  /// Persisted, because it decides whether the shell is reachable: a guest who
  /// closes the app must reopen into their feed rather than onto the sign-in
  /// screen they walked past.
  void setGuestMode(bool enabled) =>
      _update(state.copyWith(guestMode: enabled));
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// The active theme, for widgets that only care about that.
final themeModeProvider =
    Provider<AppThemeMode>((ref) => ref.watch(settingsProvider).themeMode);

/// Whether inline video and GIFs may start on their own.
final autoPlayEnabledProvider =
    Provider<bool>((ref) => ref.watch(settingsProvider).autoPlayEnabled);
