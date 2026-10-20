import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'settings_file.dart';

export 'app_settings.dart';
export 'settings_file.dart' show SettingsFile, settingsFileFor;

/// The settings as loaded at startup. `main()` overrides it with the file's
/// contents. Also tells the UI which settings need a restart: those whose
/// current value differs from this one.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

/// Where settings are saved. `null` (the default, used by tests) keeps them
/// in memory only.
final settingsFileProvider = Provider<SettingsFile?>((ref) => null);

/// Whether the last attempt to write the settings file failed. A read-only
/// file is not a failure here: `SettingsFile.readOnly` reports that.
class SettingsSaveFailedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool failed) => state = failed;
}

final settingsSaveFailedProvider =
    NotifierProvider<SettingsSaveFailedNotifier, bool>(
      SettingsSaveFailedNotifier.new,
    );

/// The current settings. Every change is saved right away, in order.
///
/// There is no debounce: there is no hook to flush one when the window
/// closes (window_manager replaces Flutter's close handler), and every
/// option so far is a discrete choice rather than a slider.
class SettingsNotifier extends Notifier<AppSettings> {
  SettingsFile? _file;
  Future<void> _writes = Future.value();

  /// Runs once. Never invalidate this provider: it would go back to the
  /// startup settings, not to the current ones.
  @override
  AppSettings build() {
    _file = ref.read(settingsFileProvider);
    return ref.read(initialSettingsProvider);
  }

  void setTheme(ThemePreference theme) => _update(state.copyWith(theme: theme));

  void setLanguage(String? languageCode) =>
      _update(state.withLanguage(languageCode));

  void setTitleBar(TitleBarPreference titleBar) =>
      _update(state.copyWith(titleBar: titleBar));

  void setSongSort(SortChoice<SongSortField> sort) =>
      _update(state.copyWith(songSort: sort));

  void setAlbumSort(SortChoice<AlbumSortField> sort) =>
      _update(state.copyWith(albumSort: sort));

  void setArtistSort(SortChoice<ArtistSortField> sort) =>
      _update(state.copyWith(artistSort: sort));

  void setAlbumsView(AlbumsView view) =>
      _update(state.copyWith(albumsView: view));

  /// Completes when every change made so far is on disk.
  @visibleForTesting
  Future<void> flush() => _writes;

  void _update(AppSettings next) {
    if (next == state) return;
    state = next;
    _save();
  }

  void _save() {
    final file = _file;
    if (file == null) return;
    final settings = state;
    // SettingsFile.save never throws, so the chain never breaks.
    _writes = _writes.then((_) async {
      final saved = await file.save(settings);
      if (ref.mounted) {
        ref.read(settingsSaveFailedProvider.notifier).set(!saved);
      }
    });
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
