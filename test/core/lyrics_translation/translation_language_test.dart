import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';

void main() {
  test('every code is unique and every googleCode is set', () {
    final codes = translationLanguages.map((l) => l.code).toList();
    expect(codes.toSet().length, codes.length);
    for (final language in translationLanguages) {
      expect(language.googleCode, isNotEmpty, reason: language.code);
      expect(language.nameKey, isNotEmpty, reason: language.code);
      expect(language.deeplCode, anyOf(isNull, isNotEmpty));
    }
  });

  test('both app languages are supported by both services', () {
    for (final code in ['vi', 'en']) {
      final language = translationLanguageFor(code);
      expect(language, isNotNull, reason: code);
      expect(language!.googleCode, isNotEmpty);
      expect(language.deeplCode, isNotNull);
    }
  });

  test('languages DeepL supports have a code', () {
    for (final code in ['hi', 'ms', 'fa']) {
      expect(translationLanguageFor(code)!.deeplCode, code.toUpperCase());
    }
  });

  test('looks up languages and rejects unknown codes', () {
    expect(translationLanguageFor('vi')?.nameKey, 'vie');
    expect(translationLanguageFor('xx'), isNull);
  });

  test('maps the special codes of each service', () {
    expect(translationLanguageFor('en')!.deeplCode, 'EN-US');
    expect(translationLanguageFor('pt')!.deeplCode, 'PT-BR');
    expect(translationLanguageFor('no')!.deeplCode, 'NB');
    expect(translationLanguageFor('he')!.googleCode, 'he');
    expect(translationLanguageFor('zh-Hans')!.googleCode, 'zh-CN');
    expect(translationLanguageFor('zh-Hant')!.googleCode, 'zh-TW');
  });

  test('baseLanguageOf lower-cases and cuts at - or _', () {
    expect(baseLanguageOf('zh_TW'), 'zh');
    expect(baseLanguageOf('EN-us'), 'en');
    expect(baseLanguageOf('vi'), 'vi');
  });

  test('baseLanguageOf folds alias codes', () {
    expect(baseLanguageOf('iw'), 'he');
    expect(baseLanguageOf('NB'), 'no');
    expect(baseLanguageOf('nn'), 'no');
  });

  group('isSameLanguage', () {
    final vi = translationLanguageFor('vi')!;
    final en = translationLanguageFor('en')!;
    final hans = translationLanguageFor('zh-Hans')!;
    final hant = translationLanguageFor('zh-Hant')!;

    test('compares base codes', () {
      expect(isSameLanguage('vi', vi), isTrue);
      expect(isSameLanguage('en-GB', en), isTrue);
      expect(isSameLanguage('ja', en), isFalse);
      expect(isSameLanguage(null, en), isFalse);
    });

    test('treats alias codes as the same language', () {
      expect(isSameLanguage('NB', translationLanguageFor('no')!), isTrue);
      expect(isSameLanguage('iw', translationLanguageFor('he')!), isTrue);
    });

    test('reads the script subtag of a Chinese tag', () {
      expect(isSameLanguage('zh-Hant-TW', hant), isTrue);
      expect(isSameLanguage('zh-Hans-CN', hans), isTrue);
      expect(isSameLanguage('zh-Hans-CN', hant), isFalse);
      expect(isSameLanguage('zh-Hant-CN', hant), isTrue);
    });

    test('matches Chinese only by script or region', () {
      expect(isSameLanguage('zh-CN', hans), isTrue);
      expect(isSameLanguage('zh-Hans', hans), isTrue);
      expect(isSameLanguage('zh-TW', hant), isTrue);
      expect(isSameLanguage('zh-Hant', hant), isTrue);
      expect(isSameLanguage('zh-TW', hans), isFalse);
      expect(isSameLanguage('zh-CN', hant), isFalse);
      expect(isSameLanguage('zh', hans), isFalse);
      expect(isSameLanguage('zh', hant), isFalse);
      expect(isSameLanguage('ja', hans), isFalse);
    });
  });

  test('a service names its other service', () {
    expect(
      LyricsTranslationService.google.other,
      LyricsTranslationService.deepl,
    );
    expect(
      LyricsTranslationService.deepl.other,
      LyricsTranslationService.google,
    );
    expect(LyricsTranslationService.deepl.name, 'deepl');
  });
}
