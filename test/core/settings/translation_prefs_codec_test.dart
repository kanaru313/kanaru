import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/translation_prefs.dart';
import 'package:kanaru/core/settings/translation_prefs_codec.dart';

void main() {
  const both = {
    LyricsTranslationService.google,
    LyricsTranslationService.deepl,
  };

  TranslationPrefs decode(Object? json) => decodeTranslationPrefs(json).$1;

  test('missing or wrong-typed input gives the defaults', () {
    for (final json in [null, 3, 'x', <Object?>[], <String, Object?>{}]) {
      expect(decode(json), const TranslationPrefs());
    }
    expect(const TranslationPrefs().show, isFalse);
    expect(const TranslationPrefs().needsNotice, isTrue);
  });

  test('every field round-trips', () {
    const prefs = TranslationPrefs(
      show: true,
      service: LyricsTranslationService.deepl,
      targetLanguage: 'vi',
      display: LyricsTranslationDisplay.replace,
      noticeAcknowledged: both,
    );

    final json = encodeTranslationPrefs(prefs);

    expect(json['service'], 'deepl');
    expect(json['display'], 'replace');
    expect(json['targetLanguage'], 'vi');
    expect(json['noticeAcknowledged'], ['google', 'deepl']);
    expect(decode(json), prefs);
  });

  test('a null target language is written and read back as null', () {
    final json = encodeTranslationPrefs(const TranslationPrefs());

    expect(json.containsKey('targetLanguage'), isTrue);
    expect(decode(json).targetLanguage, isNull);
  });

  test('unknown service or display falls back to the default', () {
    final prefs = decode(<String, Object?>{
      'service': 'bing',
      'display': 'sideways',
    });

    expect(prefs.service, LyricsTranslationService.google);
    expect(prefs.display, LyricsTranslationDisplay.underLine);
  });

  test('an unknown or non-string target language gives null', () {
    for (final value in ['xx-nope', '', 5, true]) {
      expect(
        decode(<String, Object?>{'targetLanguage': value}).targetLanguage,
        isNull,
      );
    }
  });

  test('unknown keys are returned and written back', () {
    final (prefs, extra) = decodeTranslationPrefs(<String, Object?>{
      'future': 1,
      'service': 'deepl',
    });
    final json = encodeTranslationPrefs(prefs, extra: extra);

    expect(extra, {'future': 1});
    expect(json['future'], 1);
    expect(json['service'], 'deepl');
  });

  test('acknowledged services that are not known are kept', () {
    final (prefs, extra) = decodeTranslationPrefs(<String, Object?>{
      'noticeAcknowledged': ['deepl', 'bing', 7],
    });
    final json = encodeTranslationPrefs(prefs, extra: extra);

    expect(prefs.noticeAcknowledged, {LyricsTranslationService.deepl});
    expect(json['noticeAcknowledged'], ['deepl', 'bing', 7]);
  });

  test('a list of the wrong type acknowledges nothing', () {
    expect(
      decode(<String, Object?>{'noticeAcknowledged': 'google'})
          .noticeAcknowledged,
      isEmpty,
    );
  });

  test('show without the notice for the stored service decodes as off', () {
    expect(decode(<String, Object?>{'show': true}).show, isFalse);
    expect(
      decode(<String, Object?>{
        'show': true,
        'service': 'deepl',
        'noticeAcknowledged': ['google'],
      }).show,
      isFalse,
    );
    expect(
      decode(<String, Object?>{
        'show': true,
        'noticeAcknowledged': ['google'],
      }).show,
      isTrue,
    );
  });

  test('prefs with the same acknowledged services are equal', () {
    const a = TranslationPrefs(noticeAcknowledged: both);
    const b = TranslationPrefs(
      noticeAcknowledged: {
        LyricsTranslationService.deepl,
        LyricsTranslationService.google,
      },
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const TranslationPrefs()));
  });

  test('withTargetLanguage can clear the language, copyWith keeps it', () {
    const prefs = TranslationPrefs(targetLanguage: 'vi');

    expect(prefs.copyWith(show: true).targetLanguage, 'vi');
    expect(prefs.withTargetLanguage(null).targetLanguage, isNull);
  });
}
