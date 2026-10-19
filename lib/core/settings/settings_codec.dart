import 'app_settings.dart';

/// Version written to `settings.json`. Bump it when a key changes meaning,
/// and add a migration for the old shape.
const settingsSchemaVersion = 1;

const _versionKey = 'version';
const _themeKey = 'theme';
const _languageKey = 'language';
const _titleBarKey = 'titleBar';
const _knownKeys = {_versionKey, _themeKey, _languageKey, _titleBarKey};

final _languagePattern = RegExp(r'^[a-z]{2,3}$');

/// What [decodeSettings] found in a parsed `settings.json`.
class DecodedSettings {
  const DecodedSettings(this.settings, this.version, this.unknownKeys);

  final AppSettings settings;

  /// The file's `version`; [settingsSchemaVersion] when missing or invalid.
  final int version;

  /// Top-level keys this version does not know, kept so that writing the
  /// file back does not drop what another build of Kanaru stored there.
  final Map<String, Object?> unknownKeys;
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
    ),
    version is int && version > 0 ? version : settingsSchemaVersion,
    {
      for (final MapEntry(:key, :value) in json.entries)
        if (!_knownKeys.contains(key)) key: value,
    },
  );
}

/// The JSON object for [settings], with [unknownKeys] carried over.
Map<String, Object?> encodeSettings(
  AppSettings settings, {
  Map<String, Object?> unknownKeys = const {},
}) => {
  ...unknownKeys,
  _versionKey: settingsSchemaVersion,
  _themeKey: settings.theme.name,
  _languageKey: settings.languageCode,
  _titleBarKey: settings.titleBar.name,
};

T _enumOr<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
