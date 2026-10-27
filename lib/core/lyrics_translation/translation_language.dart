/// A language lyrics can be translated into.
///
/// [code] is the app's own code: ISO 639-1 lowercase, plus `zh-Hans` and
/// `zh-Hant`. [nameKey] is the key `languageDisplayName` turns into a label.
/// [googleCode] and [deeplCode] are what each service's API expects;
/// [deeplCode] is `null` when DeepL cannot translate into the language.
class TranslationLanguage {
  const TranslationLanguage(
    this.code,
    this.nameKey,
    this.googleCode, [
    this.deeplCode,
  ]);

  final String code;
  final String nameKey;
  final String googleCode;
  final String? deeplCode;
}

// DeepL codes checked on 2026-10-27 against the table on the DeepL
// supported-languages page (developers.deepl.com). [deeplCode] stays nullable
// for languages DeepL may not offer, now or if its list changes.
const translationLanguages = <TranslationLanguage>[
  TranslationLanguage('vi', 'vie', 'vi', 'VI'),
  TranslationLanguage('en', 'eng', 'en', 'EN-US'),
  TranslationLanguage('ja', 'jpn', 'ja', 'JA'),
  TranslationLanguage('ko', 'kor', 'ko', 'KO'),
  TranslationLanguage('zh-Hans', 'zh-Hans', 'zh-CN', 'ZH-HANS'),
  TranslationLanguage('zh-Hant', 'zh-Hant', 'zh-TW', 'ZH-HANT'),
  TranslationLanguage('fr', 'fra', 'fr', 'FR'),
  TranslationLanguage('de', 'deu', 'de', 'DE'),
  TranslationLanguage('es', 'spa', 'es', 'ES'),
  TranslationLanguage('it', 'ita', 'it', 'IT'),
  TranslationLanguage('ru', 'rus', 'ru', 'RU'),
  TranslationLanguage('pt', 'por', 'pt', 'PT-BR'),
  TranslationLanguage('th', 'tha', 'th', 'TH'),
  TranslationLanguage('id', 'ind', 'id', 'ID'),
  TranslationLanguage('hi', 'hin', 'hi', 'HI'),
  TranslationLanguage('ar', 'ara', 'ar', 'AR'),
  TranslationLanguage('nl', 'nld', 'nl', 'NL'),
  TranslationLanguage('sv', 'swe', 'sv', 'SV'),
  TranslationLanguage('pl', 'pol', 'pl', 'PL'),
  TranslationLanguage('tr', 'tur', 'tr', 'TR'),
  TranslationLanguage('uk', 'ukr', 'uk', 'UK'),
  TranslationLanguage('cs', 'ces', 'cs', 'CS'),
  TranslationLanguage('el', 'ell', 'el', 'EL'),
  TranslationLanguage('fa', 'fas', 'fa', 'FA'),
  TranslationLanguage('ro', 'ron', 'ro', 'RO'),
  TranslationLanguage('ms', 'msa', 'ms', 'MS'),
  TranslationLanguage('he', 'heb', 'he', 'HE'),
  TranslationLanguage('fi', 'fin', 'fi', 'FI'),
  TranslationLanguage('da', 'dan', 'da', 'DA'),
  TranslationLanguage('no', 'nor', 'no', 'NB'),
  TranslationLanguage('hu', 'hun', 'hu', 'HU'),
  TranslationLanguage('cy', 'cym', 'cy', 'CY'),
  TranslationLanguage('sk', 'slk', 'sk', 'SK'),
  TranslationLanguage('sq', 'sqi', 'sq', 'SQ'),
  TranslationLanguage('hy', 'hye', 'hy', 'HY'),
  TranslationLanguage('eu', 'eus', 'eu', 'EU'),
  TranslationLanguage('my', 'mya', 'my', 'MY'),
  TranslationLanguage('ka', 'kat', 'ka', 'KA'),
  TranslationLanguage('is', 'isl', 'is', 'IS'),
  TranslationLanguage('mk', 'mkd', 'mk', 'MK'),
  TranslationLanguage('mi', 'mri', 'mi', 'MI'),
];

/// The entry of [translationLanguages] whose code is [code], or `null`.
TranslationLanguage? translationLanguageFor(String code) {
  for (final language in translationLanguages) {
    if (language.code == code) return language;
  }
  return null;
}

/// [code] lower-cased and cut at the first `-` or `_`: `zh_TW` is `zh`.
/// Alternative codes are folded into the one the table uses: Google's old
/// `iw` is `he`, and DeepL's `NB` and `NN` are `no`.
String baseLanguageOf(String code) {
  final lower = code.toLowerCase();
  final cut = lower.indexOf(RegExp('[-_]'));
  final base = cut < 0 ? lower : lower.substring(0, cut);
  return switch (base) {
    'iw' => 'he',
    'nb' || 'nn' => 'no',
    _ => base,
  };
}

const _simplifiedRegions = {'cn', 'sg'};
const _traditionalRegions = {'tw', 'hk', 'mo'};

/// Whether a line detected as [detected] already is in [target], so
/// translating it would only repeat it. Chinese counts as the same only when
/// the detected tag names the matching script (`zh-Hant-TW`) or, without a
/// script, region (`zh-TW`); a bare `zh` never does, because it does not say
/// which script the lyrics use.
bool isSameLanguage(String? detected, TranslationLanguage target) {
  if (detected == null || detected.isEmpty) return false;
  if (baseLanguageOf(detected) != baseLanguageOf(target.code)) return false;
  if (baseLanguageOf(target.code) != 'zh') return true;
  final subtags = detected.toLowerCase().split(RegExp('[-_]')).skip(1).toSet();
  final script = subtags.contains('hans')
      ? 'zh-Hans'
      : subtags.contains('hant')
      ? 'zh-Hant'
      : subtags.any(_simplifiedRegions.contains)
      ? 'zh-Hans'
      : subtags.any(_traditionalRegions.contains)
      ? 'zh-Hant'
      : null;
  return script == target.code;
}
