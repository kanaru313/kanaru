import 'app_settings.dart';
import 'display_prefs_codec.dart';
import 'library_scan_prefs_codec.dart';
import 'playback_prefs_codec.dart';
import 'library_sort_codec.dart';
import 'settings_codec_values.dart';
import 'translation_prefs_codec.dart';

/// Version written to `settings.json`. Bump it when a key changes meaning,
/// and add a migration for the old shape.
const settingsSchemaVersion = 1;

const _versionKey = 'version';
const _themeKey = 'theme';
const _languageKey = 'language';
const _titleBarKey = 'titleBar';
const _librarySortKey = 'librarySort';
const _albumsViewKey = 'albumsView';
const _playlistsViewKey = 'playlistsView';
const _rescanOnStartupKey = 'rescanOnStartup';
const _libraryOnboardedKey = 'libraryOnboarded';
const _recordListenHistoryKey = 'recordListenHistory';
const _animationsKey = 'animations';
const _libraryScanKey = 'libraryScan';
const _playbackKey = 'playback';
const _displayKey = 'display';
const _translationKey = 'lyricsTranslation';
const _knownKeys = {
  _versionKey,
  _themeKey,
  _languageKey,
  _titleBarKey,
  _librarySortKey,
  _albumsViewKey,
  _playlistsViewKey,
  _rescanOnStartupKey,
  _libraryOnboardedKey,
  _recordListenHistoryKey,
  _animationsKey,
  _libraryScanKey,
  _playbackKey,
  _displayKey,
  _translationKey,
};

final _languagePattern = RegExp(r'^[a-z]{2,3}$');

/// What [decodeSettings] found in a parsed `settings.json`.
class DecodedSettings {
  const DecodedSettings(
    this.settings,
    this.version,
    this.unknownKeys, [
    this.librarySortExtra = const {},
    this.groupExtras = const {},
  ]);

  final AppSettings settings;

  /// The file's `version`; [settingsSchemaVersion] when missing or invalid.
  final int version;

  /// Top-level keys this version does not know, kept so that writing the
  /// file back does not drop what another build of Kanaru stored there.
  final Map<String, Object?> unknownKeys;

  /// Screens inside `librarySort` this version does not know (for example
  /// one added by a newer build), kept for the same reason.
  final Map<String, Object?> librarySortExtra;

  /// For each of `libraryScan`, `playback`, `display` and
  /// `lyricsTranslation`: the keys inside it this version does not know,
  /// kept for the same reason.
  final Map<String, Map<String, Object?>> groupExtras;
}

/// Reads settings from decoded JSON. Never fails: a missing key, a value of
/// the wrong type or an unknown enum name gives that key's default, and
/// anything that is not an object gives all defaults.
DecodedSettings decodeSettings(Object? json) {
  if (json is! Map<String, Object?>) {
    return const DecodedSettings(AppSettings(), settingsSchemaVersion, {});
  }
  const defaults = AppSettings();
  final version = json[_versionKey];
  final language = json[_languageKey];
  final sorts = json[_librarySortKey];
  final sortJson = sorts is Map<String, Object?> ? sorts : const {};
  final (libraryScan, libraryScanExtra) = decodeLibraryScanPrefs(
    json[_libraryScanKey],
  );
  final (playback, playbackExtra) = decodePlaybackPrefs(json[_playbackKey]);
  final (display, displayExtra) = decodeDisplayPrefs(json[_displayKey]);
  final (translation, translationExtra) = decodeTranslationPrefs(
    json[_translationKey],
  );
  return DecodedSettings(
    AppSettings(
      theme: enumOr(ThemePreference.values, json[_themeKey], defaults.theme),
      languageCode: language is String && _languagePattern.hasMatch(language)
          ? language
          : defaults.languageCode,
      titleBar: enumOr(
        TitleBarPreference.values,
        json[_titleBarKey],
        defaults.titleBar,
      ),
      songSort: decodeSort(
        sortJson[songsScreen],
        SongSortField.values,
        defaults.songSort,
      ),
      albumSort: decodeSort(
        sortJson[albumsScreen],
        AlbumSortField.values,
        defaults.albumSort,
      ),
      artistSort: decodeSort(
        sortJson[artistsScreen],
        ArtistSortField.values,
        defaults.artistSort,
      ),
      albumsView: enumOr(
        AlbumsView.values,
        json[_albumsViewKey],
        defaults.albumsView,
      ),
      playlistsView: enumOr(
        AlbumsView.values,
        json[_playlistsViewKey],
        defaults.playlistsView,
      ),
      rescanOnStartup: boolOr(
        json[_rescanOnStartupKey],
        defaults.rescanOnStartup,
      ),
      libraryOnboarded: boolOr(
        json[_libraryOnboardedKey],
        defaults.libraryOnboarded,
      ),
      recordListenHistory: boolOr(
        json[_recordListenHistoryKey],
        defaults.recordListenHistory,
      ),
      animations: boolOr(json[_animationsKey], defaults.animations),
      libraryScan: libraryScan,
      playback: playback,
      display: display,
      translation: translation,
    ),
    version is int && version > 0 ? version : settingsSchemaVersion,
    {
      for (final MapEntry(:key, :value) in json.entries)
        if (!_knownKeys.contains(key)) key: value,
    },
    {
      for (final MapEntry(:key, :value) in sortJson.entries)
        if (!knownSortScreens.contains(key)) key: value,
    },
    {
      _libraryScanKey: libraryScanExtra,
      _playbackKey: playbackExtra,
      _displayKey: displayExtra,
      _translationKey: translationExtra,
    },
  );
}

/// The JSON object for [settings], with [unknownKeys] and
/// [librarySortExtra] and [groupExtras] carried over.
Map<String, Object?> encodeSettings(
  AppSettings settings, {
  Map<String, Object?> unknownKeys = const {},
  Map<String, Object?> librarySortExtra = const {},
  Map<String, Map<String, Object?>> groupExtras = const {},
}) => {
  ...unknownKeys,
  _versionKey: settingsSchemaVersion,
  _themeKey: settings.theme.name,
  _languageKey: settings.languageCode,
  _titleBarKey: settings.titleBar.name,
  _librarySortKey: {
    ...librarySortExtra,
    songsScreen: encodeSort(settings.songSort),
    albumsScreen: encodeSort(settings.albumSort),
    artistsScreen: encodeSort(settings.artistSort),
  },
  _albumsViewKey: settings.albumsView.name,
  _playlistsViewKey: settings.playlistsView.name,
  _rescanOnStartupKey: settings.rescanOnStartup,
  _libraryOnboardedKey: settings.libraryOnboarded,
  _recordListenHistoryKey: settings.recordListenHistory,
  _animationsKey: settings.animations,
  _libraryScanKey: encodeLibraryScanPrefs(
    settings.libraryScan,
    extra: groupExtras[_libraryScanKey] ?? const {},
  ),
  _playbackKey: encodePlaybackPrefs(
    settings.playback,
    extra: groupExtras[_playbackKey] ?? const {},
  ),
  _displayKey: encodeDisplayPrefs(
    settings.display,
    extra: groupExtras[_displayKey] ?? const {},
  ),
  _translationKey: encodeTranslationPrefs(
    settings.translation,
    extra: groupExtras[_translationKey] ?? const {},
  ),
};
