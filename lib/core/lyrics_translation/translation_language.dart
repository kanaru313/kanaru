/// A language lyrics can be translated into.
///
/// [code] is the app's own code: ISO 639-1 lowercase, plus `zh-Hans` and
/// `zh-Hant`. [nameKey] is the key `languageDisplayName` turns into a label.
/// [googleCode] is what Google's API expects.
class TranslationLanguage {
  const TranslationLanguage(this.code, this.nameKey, this.googleCode);

  final String code;
  final String nameKey;
  final String googleCode;
}

const translationLanguages = <TranslationLanguage>[
  TranslationLanguage('vi', 'vie', 'vi'),
  TranslationLanguage('en', 'eng', 'en'),
  TranslationLanguage('ja', 'jpn', 'ja'),
  TranslationLanguage('ko', 'kor', 'ko'),
  TranslationLanguage('zh-Hans', 'zh-Hans', 'zh-CN'),
  TranslationLanguage('zh-Hant', 'zh-Hant', 'zh-TW'),
  TranslationLanguage('fr', 'fra', 'fr'),
  TranslationLanguage('de', 'deu', 'de'),
  TranslationLanguage('es', 'spa', 'es'),
  TranslationLanguage('it', 'ita', 'it'),
  TranslationLanguage('ru', 'rus', 'ru'),
  TranslationLanguage('pt', 'por', 'pt'),
  TranslationLanguage('th', 'tha', 'th'),
  TranslationLanguage('id', 'ind', 'id'),
  TranslationLanguage('hi', 'hin', 'hi'),
  TranslationLanguage('ar', 'ara', 'ar'),
  TranslationLanguage('nl', 'nld', 'nl'),
  TranslationLanguage('sv', 'swe', 'sv'),
  TranslationLanguage('pl', 'pol', 'pl'),
  TranslationLanguage('tr', 'tur', 'tr'),
  TranslationLanguage('uk', 'ukr', 'uk'),
  TranslationLanguage('cs', 'ces', 'cs'),
  TranslationLanguage('el', 'ell', 'el'),
  TranslationLanguage('fa', 'fas', 'fa'),
  TranslationLanguage('ro', 'ron', 'ro'),
  TranslationLanguage('ms', 'msa', 'ms'),
  TranslationLanguage('he', 'heb', 'he'),
  TranslationLanguage('fi', 'fin', 'fi'),
  TranslationLanguage('da', 'dan', 'da'),
  TranslationLanguage('no', 'nor', 'no'),
  TranslationLanguage('hu', 'hun', 'hu'),
  TranslationLanguage('cy', 'cym', 'cy'),
  TranslationLanguage('sk', 'slk', 'sk'),
  TranslationLanguage('sq', 'sqi', 'sq'),
  TranslationLanguage('hy', 'hye', 'hy'),
  TranslationLanguage('eu', 'eus', 'eu'),
  TranslationLanguage('my', 'mya', 'my'),
  TranslationLanguage('ka', 'kat', 'ka'),
  TranslationLanguage('is', 'isl', 'is'),
  TranslationLanguage('mk', 'mkd', 'mk'),
  TranslationLanguage('mi', 'mri', 'mi'),
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
/// `iw` is `he`, and `nb` and `nn` are `no`.
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
