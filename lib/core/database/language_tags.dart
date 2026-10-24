/// Splits and normalizes raw language tags at read time. The language and
/// grouping code owns this file: `tracks.language` keeps the tag as written,
/// and everything that groups or labels languages goes through these helpers.
library;

/// ISO 639-1 codes of common languages mapped to their ISO 639-2/T codes.
const _iso1To2 = <String, String>{
  'en': 'eng',
  'vi': 'vie',
  'ja': 'jpn',
  'ko': 'kor',
  'zh': 'zho',
  'fr': 'fra',
  'de': 'deu',
  'es': 'spa',
  'it': 'ita',
  'ru': 'rus',
  'pt': 'por',
  'th': 'tha',
  'id': 'ind',
  'hi': 'hin',
  'ar': 'ara',
  'nl': 'nld',
  'sv': 'swe',
  'pl': 'pol',
  'tr': 'tur',
  'uk': 'ukr',
  'cs': 'ces',
  'el': 'ell',
  'fa': 'fas',
  'ro': 'ron',
  'ms': 'msa',
  'he': 'heb',
  'fi': 'fin',
  'da': 'dan',
  'no': 'nor',
  'hu': 'hun',
  'cy': 'cym',
  'sk': 'slk',
  'sq': 'sqi',
  'hy': 'hye',
  'eu': 'eus',
  'my': 'mya',
  'ka': 'kat',
  'is': 'isl',
  'mk': 'mkd',
  'mi': 'mri',
  'bo': 'bod',
};

/// ISO 639-2/B (bibliographic) codes mapped to their 639-2/T form.
const _iso2bTo2t = <String, String>{
  'fre': 'fra',
  'ger': 'deu',
  'chi': 'zho',
  'cze': 'ces',
  'dut': 'nld',
  'gre': 'ell',
  'per': 'fas',
  'rum': 'ron',
  'slo': 'slk',
  'alb': 'sqi',
  'arm': 'hye',
  'baq': 'eus',
  'bur': 'mya',
  'geo': 'kat',
  'ice': 'isl',
  'mac': 'mkd',
  'mao': 'mri',
  'may': 'msa',
  'tib': 'bod',
  'wel': 'cym',
};

/// Common English language names mapped to ISO 639-2/T codes.
const _englishNames = <String, String>{
  'english': 'eng',
  'vietnamese': 'vie',
  'japanese': 'jpn',
  'korean': 'kor',
  'chinese': 'zho',
  'french': 'fra',
  'german': 'deu',
  'spanish': 'spa',
  'italian': 'ita',
  'russian': 'rus',
  'portuguese': 'por',
  'thai': 'tha',
  'indonesian': 'ind',
  'hindi': 'hin',
  'arabic': 'ara',
};

/// Every key [languageKey] can return through one of the tables above (not
/// `zxx` and `mul`, which are never produced by a table).
final Set<String> knownLanguageKeys = Set.unmodifiable({
  ..._iso1To2.values,
  ..._iso2bTo2t.values,
  ..._englishNames.values,
});

final _separators = RegExp(r'[;/,|\u0000]');

/// A two or three letter language code followed only by BCP 47 shaped
/// subtags: a 4 letter script (`Hant`), a 2 letter region (`US`) or a 3 digit
/// region (`419`), as in `en-US`, `pt_BR`, `zh-Hant-TW`. Group 1 is the
/// language code. Longer words (`old-english`, `eng-instrumental`) do not
/// match and keep their own key.
final _regionTag = RegExp(
  r'^([a-z]{2,3})(?:[-_](?:[a-z]{4}|[a-z]{2}|\d{3}))+$',
);

/// Keys that are not shown as a language: `und` (undetermined) says nothing
/// about the song, so such tracks count as untagged. `zxx` (no linguistic
/// content, instrumentals) and `mul` (several languages) are real keys with
/// their own labels.
const hiddenLanguageKeys = {'und'};

/// The grouping key of one language value: trimmed and lower-cased, a region
/// or script subtag dropped (`en-US` is `en`), then mapped to its ISO 639-2/T
/// code when it is a known ISO 639-1 code, a 639-2/B code or a common English
/// name. Other values stay lower-cased, so `"fre"`, `"fra"`, `"fr"` and
/// `"fr-CA"` share a key and `"x-klingon"` keeps its own.
String languageKey(String value) {
  var lower = value.trim().toLowerCase();
  final base = _regionTag.firstMatch(lower)?.group(1);
  if (base != null) lower = base;
  return _iso1To2[lower] ?? _iso2bTo2t[lower] ?? _englishNames[lower] ?? lower;
}

/// The distinct languages in [raw], split on `;`, `/`, `,`, `|` and NUL.
/// Values are trimmed, empty ones dropped, and duplicates (same
/// [languageKey]) removed, keeping the first spelling seen.
List<String> splitLanguages(String? raw) {
  if (raw == null) return const [];
  final seen = <String>{};
  final out = <String>[];
  for (final part in raw.split(_separators)) {
    final value = part.trim();
    if (value.isNotEmpty && seen.add(languageKey(value))) out.add(value);
  }
  return out;
}
