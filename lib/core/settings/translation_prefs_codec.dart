import '../lyrics_translation/translation_language.dart';
import '../lyrics_translation/translation_service.dart';
import 'settings_codec_values.dart';
import 'translation_prefs.dart';

const _showKey = 'show';
const _serviceKey = 'service';
const _targetLanguageKey = 'targetLanguage';
const _displayKey = 'display';
const _noticeAcknowledgedKey = 'noticeAcknowledged';
const _knownKeys = {
  _showKey,
  _serviceKey,
  _targetLanguageKey,
  _displayKey,
  _noticeAcknowledgedKey,
};

/// Reads the `lyricsTranslation` object; each key falls back on its own. The
/// second value holds the keys this version does not know, plus (under
/// `noticeAcknowledged`) the service names it does not know, so that saving
/// keeps them.
///
/// `show` is read as off when the chosen service was never acknowledged, so a
/// hand-edited file cannot send lyrics without the notice.
(TranslationPrefs, Map<String, Object?>) decodeTranslationPrefs(Object? json) {
  final map = objectOrEmpty(json);
  const d = TranslationPrefs();
  final service = enumOr(
    LyricsTranslationService.values,
    map[_serviceKey],
    d.service,
  );
  final (acknowledged, unknownNames) = _decodeAcknowledged(
    map[_noticeAcknowledgedKey],
  );
  final target = map[_targetLanguageKey];
  return (
    TranslationPrefs(
      show: boolOr(map[_showKey], d.show) && acknowledged.contains(service),
      service: service,
      targetLanguage: target is String && translationLanguageFor(target) != null
          ? target
          : d.targetLanguage,
      display: enumOr(
        LyricsTranslationDisplay.values,
        map[_displayKey],
        d.display,
      ),
      noticeAcknowledged: acknowledged,
    ),
    {
      ...unknownEntries(map, _knownKeys),
      if (unknownNames.isNotEmpty) _noticeAcknowledgedKey: unknownNames,
    },
  );
}

(Set<LyricsTranslationService>, List<Object?>) _decodeAcknowledged(
  Object? json,
) {
  if (json is! List) return (const {}, const []);
  return (
    Set.unmodifiable({
      for (final service in LyricsTranslationService.values)
        if (json.contains(service.name)) service,
    }),
    [
      for (final name in json)
        if (!LyricsTranslationService.values.any((s) => s.name == name)) name,
    ],
  );
}

/// The `lyricsTranslation` object, with [extra] (unknown keys and service
/// names) carried over.
Map<String, Object?> encodeTranslationPrefs(
  TranslationPrefs prefs, {
  Map<String, Object?> extra = const {},
}) {
  final unknownNames = extra[_noticeAcknowledgedKey];
  return {
    ...extra,
    _showKey: prefs.show,
    _serviceKey: prefs.service.name,
    _targetLanguageKey: prefs.targetLanguage,
    _displayKey: prefs.display.name,
    _noticeAcknowledgedKey: [
      for (final service in LyricsTranslationService.values)
        if (prefs.noticeAcknowledged.contains(service)) service.name,
      if (unknownNames is List) ...unknownNames,
    ],
  };
}
