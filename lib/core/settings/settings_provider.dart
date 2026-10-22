import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'app_settings.dart';
import 'settings_file.dart';

export 'app_settings.dart';
export 'settings_file.dart' show SettingsFile, settingsFileFor;

final _log = Logger('settings');

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

/// The current settings. Every change is saved right away; changes that come
/// while a write is running are merged into one write of the latest state.
///
/// File writes are not debounced (applying a theme or language is delayed
/// separately, in `applied_appearance_provider.dart`): there is no hook to
/// flush one when the window closes (window_manager replaces Flutter's close
/// handler), and every option so far is a discrete choice rather than a
/// slider.
class SettingsNotifier extends Notifier<AppSettings> {
  SettingsFile? _file;
  Future<void>? _inFlight;
  AppSettings? _pending;

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

  void setRescanOnStartup(bool enabled) =>
      _update(state.copyWith(rescanOnStartup: enabled));

  void setRecordListenHistory(bool enabled) =>
      _update(state.copyWith(recordListenHistory: enabled));

  void setAnimations(bool enabled) =>
      _update(state.copyWith(animations: enabled));

  // The group setters write every option of a group (scan, playback,
  // display). An option's settings row calls them once the option is wired;
  // rows of options not wired yet are disabled and do not.
  void setLibraryScan(LibraryScanPrefs prefs) =>
      _update(state.copyWith(libraryScan: prefs));

  void setPlayback(PlaybackPrefs prefs) =>
      _update(state.copyWith(playback: prefs));

  void setDisplay(DisplayPrefs prefs) =>
      _update(state.copyWith(display: prefs));

  /// Records that the first-run source picker is done for good.
  void markLibraryOnboarded() =>
      _update(state.copyWith(libraryOnboarded: true));

  /// Completes when every change made so far is on disk: nothing is being
  /// written and nothing is waiting.
  @visibleForTesting
  Future<void> flush() async {
    while (_inFlight != null) {
      await _inFlight;
    }
  }

  void _update(AppSettings next) {
    if (next == state) return;
    state = next;
    _save();
  }

  /// At most one write runs and one waits. A change made during a write
  /// replaces the waiting one, so a burst writes the first and the last state.
  void _save() {
    if (_file == null) return;
    _pending = state;
    // Started on a later event, so `_inFlight` is set before any of the drain
    // runs (even if it finishes without awaiting) and is cleared after.
    _inFlight ??= Future<void>(_drain);
  }

  Future<void> _drain() async {
    final file = _file!;
    try {
      while (_pending != null) {
        final settings = _pending!;
        _pending = null;
        var saved = false;
        try {
          saved = await file.save(settings);
        } catch (error, stack) {
          // SettingsFile.save should not throw; if it does, treat it as a
          // failed write and keep draining so later changes still get saved.
          _log.warning('Saving settings threw', error, stack);
        }
        // Only the last write of a burst decides the warning, so a failure
        // that a queued write is about to fix never flashes.
        if (_pending == null && ref.mounted) {
          ref.read(settingsSaveFailedProvider.notifier).set(!saved);
        }
      }
    } finally {
      _inFlight = null;
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
