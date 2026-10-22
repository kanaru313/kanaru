import 'app_settings.dart';

/// Version written to `settings.json`. Bump it when a key changes meaning,
/// and add a migration for the old shape.
const settingsSchemaVersion = 1;

const _versionKey = 'version';
const _themeKey = 'theme';
const _languageKey = 'language';
const _titleBarKey = 'titleBar';
const _librarySortKey = 'librarySort';
const _albumsViewKey = 'albumsView';
const _rescanOnStartupKey = 'rescanOnStartup';
const _libraryOnboardedKey = 'libraryOnboarded';
const _recordListenHistoryKey = 'recordListenHistory';
const _animationsKey = 'animations';
const _knownKeys = {
  _versionKey,
  _themeKey,
  _languageKey,
  _titleBarKey,
  _librarySortKey,
  _albumsViewKey,
  _rescanOnStartupKey,
  _libraryOnboardedKey,
  _recordListenHistoryKey,
  _animationsKey,
};

// Screens inside `librarySort`, and the fields of each.
const _songsScreen = 'songs';
const _albumsScreen = 'albums';
const _artistsScreen = 'artists';
const _knownScreens = {_songsScreen, _albumsScreen, _artistsScreen};
const _byKey = 'by';
const _descendingKey = 'descending';

final _languagePattern = RegExp(r'^[a-z]{2,3}$');

/// What [decodeSettings] found in a parsed `settings.json`.
class DecodedSettings {
  const DecodedSettings(
    this.settings,
    this.version,
    this.unknownKeys, [
    this.librarySortExtra = const {},
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
  return DecodedSettings(
    AppSettings(
      theme: _enumOr(ThemePreference.values, json[_themeKey], defaults.theme),
      languageCode: language is String && _languagePattern.hasMatch(language)
          ? language
          : defaults.languageCode,
      titleBar: _enumOr(
        TitleBarPreference.values,
        json[_titleBarKey],
        defaults.titleBar,
      ),
      songSort: _decodeSort(
        sortJson[_songsScreen],
        SongSortField.values,
        defaults.songSort,
      ),
      albumSort: _decodeSort(
        sortJson[_albumsScreen],
        AlbumSortField.values,
        defaults.albumSort,
      ),
      artistSort: _decodeSort(
        sortJson[_artistsScreen],
        ArtistSortField.values,
        defaults.artistSort,
      ),
      albumsView: _enumOr(
        AlbumsView.values,
        json[_albumsViewKey],
        defaults.albumsView,
      ),
      rescanOnStartup: _boolOr(
        json[_rescanOnStartupKey],
        defaults.rescanOnStartup,
      ),
      libraryOnboarded: _boolOr(
        json[_libraryOnboardedKey],
        defaults.libraryOnboarded,
      ),
      recordListenHistory: _boolOr(
        json[_recordListenHistoryKey],
        defaults.recordListenHistory,
      ),
      animations: _boolOr(json[_animationsKey], defaults.animations),
    ),
    version is int && version > 0 ? version : settingsSchemaVersion,
    {
      for (final MapEntry(:key, :value) in json.entries)
        if (!_knownKeys.contains(key)) key: value,
    },
    {
      for (final MapEntry(:key, :value) in sortJson.entries)
        if (!_knownScreens.contains(key)) key: value,
    },
  );
}

/// The JSON object for [settings], with [unknownKeys] and
/// [librarySortExtra] carried over.
Map<String, Object?> encodeSettings(
  AppSettings settings, {
  Map<String, Object?> unknownKeys = const {},
  Map<String, Object?> librarySortExtra = const {},
}) => {
  ...unknownKeys,
  _versionKey: settingsSchemaVersion,
  _themeKey: settings.theme.name,
  _languageKey: settings.languageCode,
  _titleBarKey: settings.titleBar.name,
  _librarySortKey: {
    ...librarySortExtra,
    _songsScreen: _encodeSort(settings.songSort),
    _albumsScreen: _encodeSort(settings.albumSort),
    _artistsScreen: _encodeSort(settings.artistSort),
  },
  _albumsViewKey: settings.albumsView.name,
  _rescanOnStartupKey: settings.rescanOnStartup,
  _libraryOnboardedKey: settings.libraryOnboarded,
  _recordListenHistoryKey: settings.recordListenHistory,
  _animationsKey: settings.animations,
};

/// Each part falls back on its own: a bad `by` keeps a valid `descending`.
SortChoice<F> _decodeSort<F extends Enum>(
  Object? json,
  List<F> values,
  SortChoice<F> fallback,
) {
  if (json is! Map<String, Object?>) return fallback;
  final descending = json[_descendingKey];
  return SortChoice(
    _enumOr(values, json[_byKey], fallback.field),
    descending: descending is bool ? descending : fallback.descending,
  );
}

Map<String, Object?> _encodeSort(SortChoice<Enum> choice) => {
  _byKey: choice.field.name,
  _descendingKey: choice.descending,
};

bool _boolOr(Object? value, bool fallback) => value is bool ? value : fallback;

T _enumOr<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
