import '../l10n/l10n.dart';
import 'language_summaries.dart';

/// What a language is called on screen: the translated name of its [key]
/// (every key in `knownLanguageKeys`, plus `zxx` for instrumentals and `mul`
/// for several languages), or the [key] upper-cased for a key with no
/// translation (`x-klingon` shows as `X-KLINGON`), so the label does not
/// depend on which spellings the library holds.
String languageDisplayName(AppLocalizations l10n, String key) => switch (key) {
  'eng' => l10n.languageNameEng,
  'vie' => l10n.languageNameVie,
  'jpn' => l10n.languageNameJpn,
  'kor' => l10n.languageNameKor,
  'zho' => l10n.languageNameZho,
  'fra' => l10n.languageNameFra,
  'deu' => l10n.languageNameDeu,
  'spa' => l10n.languageNameSpa,
  'ita' => l10n.languageNameIta,
  'rus' => l10n.languageNameRus,
  'por' => l10n.languageNamePor,
  'tha' => l10n.languageNameTha,
  'ind' => l10n.languageNameInd,
  'hin' => l10n.languageNameHin,
  'ara' => l10n.languageNameAra,
  'nld' => l10n.languageNameNld,
  'swe' => l10n.languageNameSwe,
  'pol' => l10n.languageNamePol,
  'tur' => l10n.languageNameTur,
  'ukr' => l10n.languageNameUkr,
  'ces' => l10n.languageNameCes,
  'ell' => l10n.languageNameEll,
  'fas' => l10n.languageNameFas,
  'ron' => l10n.languageNameRon,
  'msa' => l10n.languageNameMsa,
  'heb' => l10n.languageNameHeb,
  'fin' => l10n.languageNameFin,
  'dan' => l10n.languageNameDan,
  'nor' => l10n.languageNameNor,
  'hun' => l10n.languageNameHun,
  'cym' => l10n.languageNameCym,
  'slk' => l10n.languageNameSlk,
  'sqi' => l10n.languageNameSqi,
  'hye' => l10n.languageNameHye,
  'eus' => l10n.languageNameEus,
  'mya' => l10n.languageNameMya,
  'kat' => l10n.languageNameKat,
  'isl' => l10n.languageNameIsl,
  'mkd' => l10n.languageNameMkd,
  'mri' => l10n.languageNameMri,
  'bod' => l10n.languageNameBod,
  'zxx' => l10n.languageNameZxx,
  'mul' => l10n.languageNameMul,
  _ => key.toUpperCase(),
};

/// [languageDisplayName] of [summary].
String languageSummaryName(AppLocalizations l10n, LanguageSummary summary) =>
    languageDisplayName(l10n, summary.key);
