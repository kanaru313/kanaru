import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/language_tags.dart';

void main() {
  group('splitLanguages', () {
    test('a single code is kept as written, trimmed', () {
      expect(splitLanguages('vie'), ['vie']);
      expect(splitLanguages(' VI '), ['VI']);
    });

    test('splits on every separator', () {
      expect(splitLanguages('eng/jpn'), ['eng', 'jpn']);
      expect(splitLanguages('eng;jpn, kor|vie'), ['eng', 'jpn', 'kor', 'vie']);
      expect(splitLanguages('eng\u0000jpn'), ['eng', 'jpn']);
    });

    test('drops duplicates by key and keeps the first spelling', () {
      expect(splitLanguages('English; english'), ['English']);
      expect(splitLanguages('fre; fra, fr'), ['fre']);
    });

    test('null, empty and separator-only input give no languages', () {
      expect(splitLanguages(null), isEmpty);
      expect(splitLanguages(''), isEmpty);
      expect(splitLanguages('  ; / '), isEmpty);
    });

    test('unknown values are kept', () {
      expect(splitLanguages('x-klingon'), ['x-klingon']);
    });
  });

  group('languageKey', () {
    test('ISO 639-1, 639-2/B and 639-2/T spellings share a key', () {
      expect(languageKey('fre'), 'fra');
      expect(languageKey('fra'), 'fra');
      expect(languageKey('fr'), 'fra');
      expect(languageKey(' DE '), 'deu');
      expect(languageKey('ger'), 'deu');
      expect(languageKey('wel'), 'cym');
      expect(languageKey('cy'), 'cym');
      for (final alias in ['sk', 'slo', 'slk']) {
        expect(languageKey(alias), 'slk');
      }
      for (final alias in ['is', 'ice', 'isl']) {
        expect(languageKey(alias), 'isl');
      }
    });

    test('English names map to codes, ignoring case', () {
      expect(languageKey('Vietnamese'), 'vie');
      expect(languageKey('JAPANESE'), 'jpn');
      expect(languageKey('english'), languageKey('en'));
    });

    test('other values stay lower-cased', () {
      expect(languageKey(' X-Klingon '), 'x-klingon');
      expect(languageKey('xyz'), 'xyz');
    });

    test('a region or script subtag is dropped', () {
      expect(languageKey('en-US'), 'eng');
      expect(languageKey('pt_BR'), 'por');
      expect(languageKey('zh-Hant'), 'zho');
      expect(languageKey('fre-CA'), 'fra');
      expect(languageKey('x-klingon'), 'x-klingon');
      expect(splitLanguages('en-US; en-GB, eng'), ['en-US']);
    });

    test('only BCP 47 shaped subtags are dropped', () {
      for (final (value, key) in [
        ('en-US', 'eng'),
        ('pt_BR', 'por'),
        ('zh-Hant', 'zho'),
        ('zh-Hant-TW', 'zho'),
        ('es-419', 'spa'),
        ('fre-CA', 'fra'),
      ]) {
        expect(languageKey(value), key, reason: value);
      }
      for (final value in [
        'old-english',
        'old-norse',
        'non-english',
        'eng-instrumental',
      ]) {
        expect(languageKey(value), value, reason: value);
      }
    });

    test('und is hidden, zxx and mul are real keys', () {
      expect(hiddenLanguageKeys, {'und'});
      expect(languageKey('UND'), 'und');
      expect(languageKey('zxx'), 'zxx');
      expect(languageKey('mul'), 'mul');
      expect(knownLanguageKeys, isNot(contains('zxx')));
    });

    test('known keys include the mapped codes and not raw spellings', () {
      expect(knownLanguageKeys, containsAll(['eng', 'vie', 'fra', 'cym']));
      expect(knownLanguageKeys, isNot(contains('fre')));
      expect(knownLanguageKeys, isNot(contains('x-klingon')));
    });
  });
}
