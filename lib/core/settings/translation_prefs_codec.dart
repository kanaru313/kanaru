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
/// `noticeAcknowledged`) the service ids it does not know, so that saving
/// keeps them.
///
/// `show` is read as off when the chosen service was never acknowledged, so a
/// hand-edited file cannot send lyrics without the notice.
(TranslationPrefs, Map<String, Object?>) decodeTranslationPrefs(Object? json) {
  final map = objectOrEmpty(json);
  const d = TranslationPrefs();
  final service = TranslationServiceId.tryParse(map[_serviceKey]) ?? d.service;
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

/// Most acknowledged services kept; a hand-edited file cannot grow the set.
const _maxAcknowledged = 64;

(Set<TranslationServiceId>, List<Object?>) _decodeAcknowledged(Object? json) {
  if (json is! List) return (const {}, const []);
  final known = <TranslationServiceId>{};
  final unknown = <Object?>[];
  for (final item in json) {
    final id = TranslationServiceId.tryParse(item);
    if (id == null) {
      unknown.add(item);
    } else if (known.length < _maxAcknowledged) {
      known.add(id);
    }
  }
  return (Set.unmodifiable(known), unknown);
}

/// The `lyricsTranslation` object, with [extra] (unknown keys and service
/// ids) carried over.
Map<String, Object?> encodeTranslationPrefs(
  TranslationPrefs prefs, {
  Map<String, Object?> extra = const {},
}) {
  final unknownNames = extra[_noticeAcknowledgedKey];
  return {
    ...extra,
    _showKey: prefs.show,
    _serviceKey: prefs.service.value,
    _targetLanguageKey: prefs.targetLanguage,
    _displayKey: prefs.display.name,
    _noticeAcknowledgedKey: [
      for (final service in prefs.noticeAcknowledged) service.value,
      if (unknownNames is List) ...unknownNames,
    ],
  };
}
