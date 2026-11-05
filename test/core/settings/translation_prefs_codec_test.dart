import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/translation_prefs.dart';
import 'package:kanaru/core/settings/translation_prefs_codec.dart';

void main() {
  const both = {TranslationServiceId.google};

  TranslationPrefs decode(Object? json) => decodeTranslationPrefs(json).$1;

  test('missing or wrong-typed input gives the defaults', () {
    for (final json in [null, 3, 'x', <Object?>[], <String, Object?>{}]) {
      expect(decode(json), const TranslationPrefs());
    }
    expect(const TranslationPrefs().service, isNull);
    expect(const TranslationPrefs().show, isFalse);
    expect(const TranslationPrefs().needsNotice, isTrue);
  });

  test('every field round-trips', () {
    const prefs = TranslationPrefs(
      show: true,
      service: TranslationServiceId.google,
      targetLanguage: 'vi',
      display: LyricsTranslationDisplay.replace,
      noticeAcknowledged: both,
    );

    final json = encodeTranslationPrefs(prefs);

    expect(json['service'], 'google');
    expect(json['display'], 'replace');
    expect(json['targetLanguage'], 'vi');
    expect(json['noticeAcknowledged'], ['google']);
    expect(decode(json), prefs);
  });

  test('a null target language is written and read back as null', () {
    final json = encodeTranslationPrefs(const TranslationPrefs());

    expect(json.containsKey('targetLanguage'), isTrue);
    expect(decode(json).targetLanguage, isNull);
  });

  test('unknown service falls back to null, unknown display falls back to the default', () {
    final prefs = decode(<String, Object?>{
      'service': 'bing',
      'display': 'sideways',
    });

    expect(prefs.service, isNull);
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
    });
    final json = encodeTranslationPrefs(prefs, extra: extra);

    expect(extra, {'future': 1});
    expect(json['future'], 1);
  });

  test('a saved DeepL service loads as null', () {
    final prefs = decode(<String, Object?>{'service': 'deepl'});

    expect(prefs.service, isNull);
  });

  test('acknowledged services that are not known are kept', () {
    final (prefs, extra) = decodeTranslationPrefs(<String, Object?>{
      'noticeAcknowledged': ['deepl', 'bing', 7],
    });
    final json = encodeTranslationPrefs(prefs, extra: extra);

    expect(prefs.noticeAcknowledged, isEmpty);
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
        'noticeAcknowledged': ['deepl'],
      }).show,
      isFalse,
    );
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
      isFalse,
    );
    expect(
      decode(<String, Object?>{
        'show': true,
        'service': 'google',
        'noticeAcknowledged': ['google'],
      }).show,
      isTrue,
    );
  });

  test('prefs with the same acknowledged services are equal', () {
    const a = TranslationPrefs(noticeAcknowledged: both);
    const b = TranslationPrefs(
      noticeAcknowledged: {TranslationServiceId.google},
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

  group('plugin ids', () {
    final id = TranslationServiceId.tryParse('plugin-abc123def456')!;

    test('a plugin id is kept as the service and as accepted', () {
      final prefs = decode(<String, Object?>{
        'show': true,
        'service': id.value,
        'noticeAcknowledged': ['google', id.value],
      });

      expect(prefs.service, id);
      expect(prefs.show, isTrue);
      expect(prefs.noticeAcknowledged, {TranslationServiceId.google, id});
    });

    test('deepl and malformed ids fall back to null, kept in extra', () {
      final (prefs, extra) = decodeTranslationPrefs(<String, Object?>{
        'service': 'deepl',
        'noticeAcknowledged': ['deepl', 'plugin-x', 'google'],
      });

      expect(prefs.service, isNull);
      expect(prefs.noticeAcknowledged, {TranslationServiceId.google});
      expect(extra['noticeAcknowledged'], ['deepl', 'plugin-x']);
      final json = encodeTranslationPrefs(prefs, extra: extra);
      expect(json['service'], isNull);
      expect(json['noticeAcknowledged'], ['google', 'deepl', 'plugin-x']);
    });

    test('withoutService clears the service and show, keeps other fields', () {
      final prefs = TranslationPrefs(
        show: true,
        service: id,
        targetLanguage: 'vi',
        display: LyricsTranslationDisplay.replace,
        noticeAcknowledged: {id},
      );

      final reset = prefs.withoutService();

      expect(reset.show, isFalse);
      expect(reset.service, isNull);
      expect(reset.targetLanguage, 'vi');
      expect(reset.display, LyricsTranslationDisplay.replace);
      expect(reset.noticeAcknowledged, {id});
    });

    test('show is off when the stored plugin was never accepted', () {
      final prefs = decode(<String, Object?>{
        'show': true,
        'service': id.value,
        'noticeAcknowledged': ['google'],
      });

      expect(prefs.show, isFalse);
    });

    test('at most 64 accepted ids are kept', () {
      final ids = [
        for (var i = 0; i < 65; i++) 'plugin-${i.toString().padLeft(12, '0')}',
      ];
      final prefs = decode(<String, Object?>{'noticeAcknowledged': ids});

      expect(prefs.noticeAcknowledged, hasLength(64));
    });

    test('a plugin service round-trips', () {
      final prefs = TranslationPrefs(
        show: true,
        service: id,
        noticeAcknowledged: {id},
      );

      expect(decode(encodeTranslationPrefs(prefs)), prefs);
    });
  });
}
