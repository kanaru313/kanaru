import 'online_lyrics_prefs.dart';
import 'settings_codec_values.dart';

const _autoFetchKey = 'autoFetch';
const _manualConsentKey = 'manualConsent';
const _autoConsentKey = 'autoConsent';

/// Written by older versions: a list of per-source consent keys
/// (`<id>@<hosts>` for a search, `<id>@<hosts>:auto` for an automatic
/// lookup). It is read once to migrate the consent and never written, so it
/// is known here and dropped on save instead of carried along.
const _legacyConsentKeysKey = 'noticeAcknowledged';

/// Written by older versions to turn on `.lrc` writing on a pick. Known so
/// that it is dropped on read, and never written.
const _legacyWriteLrcKey = 'writeLrc';
const _knownKeys = {
  _autoFetchKey,
  _manualConsentKey,
  _autoConsentKey,
  _legacyConsentKeysKey,
  _legacyWriteLrcKey,
};

/// Reads the `onlineLyrics` object; each key falls back on its own. The
/// second value holds the keys this version does not know, so that saving
/// keeps them.
///
/// When neither consent flag is stored, the legacy consent list is migrated:
/// a string with `@` grants the manual consent, and one ending `:auto`
/// grants the automatic consent and, as the old code always stored both
/// together, the manual one too. Stored flags win over the legacy list.
///
/// `autoFetch` is read as off unless the automatic consent is given, so a
/// hand-edited file cannot start requests without the notice.
(OnlineLyricsPrefs, Map<String, Object?>) decodeOnlineLyricsPrefs(
  Object? json,
) {
  final map = objectOrEmpty(json);
  const d = OnlineLyricsPrefs();
  var manual = boolOr(map[_manualConsentKey], d.manualConsent);
  var auto = boolOr(map[_autoConsentKey], d.autoConsent);
  if (!map.containsKey(_manualConsentKey) &&
      !map.containsKey(_autoConsentKey)) {
    final legacy = map[_legacyConsentKeysKey];
    final keys = legacy is List ? legacy.whereType<String>() : const <String>[];
    for (final key in keys) {
      if (key.endsWith(':auto')) {
        auto = true;
        manual = true;
      } else if (key.contains('@')) {
        manual = true;
      }
    }
  }
  return (
    OnlineLyricsPrefs(
      autoFetch: boolOr(map[_autoFetchKey], d.autoFetch) && auto,
      manualConsent: manual,
      autoConsent: auto,
    ),
    unknownEntries(map, _knownKeys),
  );
}

/// The `onlineLyrics` object, with [extra] (unknown keys) carried over.
Map<String, Object?> encodeOnlineLyricsPrefs(
  OnlineLyricsPrefs prefs, {
  Map<String, Object?> extra = const {},
}) => {
  ...extra,
  _autoFetchKey: prefs.autoFetch,
  _manualConsentKey: prefs.manualConsent,
  _autoConsentKey: prefs.autoConsent,
};
