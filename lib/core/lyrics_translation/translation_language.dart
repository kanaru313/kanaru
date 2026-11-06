/// A language lyrics can be translated into.
///
/// [code] is the app's own code: ISO 639-1 lowercase, plus `zh-Hans` and
/// `zh-Hant`. [nameKey] is the key `languageDisplayName` turns into a label.
class TranslationLanguage {
  const TranslationLanguage(this.code, this.nameKey);

  final String code;
  final String nameKey;
}

const translationLanguages = <TranslationLanguage>[
  TranslationLanguage('vi', 'vie'),
  TranslationLanguage('en', 'eng'),
  TranslationLanguage('ja', 'jpn'),
  TranslationLanguage('ko', 'kor'),
  TranslationLanguage('zh-Hans', 'zh-Hans'),
  TranslationLanguage('zh-Hant', 'zh-Hant'),
  TranslationLanguage('fr', 'fra'),
  TranslationLanguage('de', 'deu'),
  TranslationLanguage('es', 'spa'),
  TranslationLanguage('it', 'ita'),
  TranslationLanguage('ru', 'rus'),
  TranslationLanguage('pt', 'por'),
  TranslationLanguage('th', 'tha'),
  TranslationLanguage('id', 'ind'),
  TranslationLanguage('hi', 'hin'),
  TranslationLanguage('ar', 'ara'),
  TranslationLanguage('nl', 'nld'),
  TranslationLanguage('sv', 'swe'),
  TranslationLanguage('pl', 'pol'),
  TranslationLanguage('tr', 'tur'),
  TranslationLanguage('uk', 'ukr'),
  TranslationLanguage('cs', 'ces'),
  TranslationLanguage('el', 'ell'),
  TranslationLanguage('fa', 'fas'),
  TranslationLanguage('ro', 'ron'),
  TranslationLanguage('ms', 'msa'),
  TranslationLanguage('he', 'heb'),
  TranslationLanguage('fi', 'fin'),
  TranslationLanguage('da', 'dan'),
  TranslationLanguage('no', 'nor'),
  TranslationLanguage('hu', 'hun'),
  TranslationLanguage('cy', 'cym'),
  TranslationLanguage('sk', 'slk'),
  TranslationLanguage('sq', 'sqi'),
  TranslationLanguage('hy', 'hye'),
  TranslationLanguage('eu', 'eus'),
  TranslationLanguage('my', 'mya'),
  TranslationLanguage('ka', 'kat'),
  TranslationLanguage('is', 'isl'),
  TranslationLanguage('mk', 'mkd'),
  TranslationLanguage('mi', 'mri'),
];

/// The entry of [translationLanguages] whose code is [code], or `null`.
TranslationLanguage? translationLanguageFor(String code) {
  for (final language in translationLanguages) {
    if (language.code == code) return language;
  }
  return null;
}

/// [code] lower-cased and cut at the first `-` or `_`: `zh_TW` is `zh`.
/// Alternative codes are folded into the one the table uses: legacy `iw`
/// is `he`, and `nb` and `nn` are `no`.
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
