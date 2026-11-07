import '../lyrics_translation/translation_language.dart';
import '../lyrics_translation/translation_scope.dart'
    show TranslationScopePrecedence;
import '../lyrics_translation/translation_service.dart';
import 'settings_codec_values.dart';
import 'translation_prefs.dart';

const _showKey = 'show';
const _serviceKey = 'service';
const _targetLanguageKey = 'targetLanguage';
const _displayKey = 'display';
const _noticeAcknowledgedKey = 'noticeAcknowledged';
const _allChosenAtKey = 'allChosenAt';
const _scopePrecedenceKey = 'scopePrecedence';
const _knownKeys = {
  _showKey,
  _serviceKey,
  _targetLanguageKey,
  _displayKey,
  _noticeAcknowledgedKey,
  _allChosenAtKey,
  _scopePrecedenceKey,
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
  final service = TranslationServiceId.tryParse(map[_serviceKey]);
  final (acknowledged, unknownNames) = _decodeAcknowledged(
    map[_noticeAcknowledgedKey],
  );
  final target = map[_targetLanguageKey];
  return (
    TranslationPrefs(
      show:
          boolOr(map[_showKey], d.show) &&
          service != null &&
          acknowledged.contains(service),
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
      allChosenAt: map[_allChosenAtKey] is int
          ? map[_allChosenAtKey] as int
          : null,
      scopePrecedence: enumOr(
        TranslationScopePrecedence.values,
        map[_scopePrecedenceKey],
        d.scopePrecedence,
      ),
    ),
    {
      ...unknownEntries(map, _knownKeys),
      if (unknownNames.isNotEmpty) _noticeAcknowledgedKey: unknownNames,
    },
  );
}

/// Most acknowledged services kept; a hand-edited file cannot grow the set.
const _maxAcknowledged = 64;

/// Built-in service ids retired in earlier builds; their consent is dropped on
/// decode so it does not linger in `extra` when settings are saved again.
const _retiredServiceIds = {'google'};

(Set<TranslationServiceId>, List<Object?>) _decodeAcknowledged(Object? json) {
  if (json is! List) return (const {}, const []);
  final known = <TranslationServiceId>{};
  final unknown = <Object?>[];
  for (final item in json) {
    if (_retiredServiceIds.contains(item)) continue;
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
    _serviceKey: prefs.service?.value,
    _targetLanguageKey: prefs.targetLanguage,
    _displayKey: prefs.display.name,
    _allChosenAtKey: prefs.allChosenAt,
    _scopePrecedenceKey: prefs.scopePrecedence.name,
    _noticeAcknowledgedKey: [
      for (final service in prefs.noticeAcknowledged) service.value,
      if (unknownNames is List) ...unknownNames,
    ],
  };
}
