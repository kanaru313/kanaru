import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/translation_prefs.dart';
import 'package:kanaru/core/settings/translation_prefs_codec.dart';

void main() {
  final plugin = TranslationServiceId.tryParse('plugin-abc123def456')!;
  final both = {plugin};

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
    final prefs = TranslationPrefs(
      show: true,
      service: plugin,
      targetLanguage: 'vi',
      display: LyricsTranslationDisplay.replace,
      noticeAcknowledged: both,
    );

    final json = encodeTranslationPrefs(prefs);

    expect(json['service'], plugin.value);
    expect(json['display'], 'replace');
    expect(json['targetLanguage'], 'vi');
    expect(json['noticeAcknowledged'], [plugin.value]);
    expect(decode(json), prefs);
  });

  test('allChosenAt round-trips and anything but an int reads as null', () {
    final prefs = TranslationPrefs(service: plugin, allChosenAt: 1700000000000);
    final json = encodeTranslationPrefs(prefs);
    expect(json['allChosenAt'], 1700000000000);
    expect(decode(json).allChosenAt, 1700000000000);
    for (final bad in <Object?>['5', 1.5, true, null]) {
      expect(decode(<String, Object?>{'allChosenAt': bad}).allChosenAt, isNull);
    }
    expect(decode(<String, Object?>{}).allChosenAt, isNull);
  });

  test('allChosenAt is part of equality, hash and copies', () {
    final a = TranslationPrefs(service: plugin, allChosenAt: 1);
    expect(a, TranslationPrefs(service: plugin, allChosenAt: 1));
    expect(
      a.hashCode,
      TranslationPrefs(service: plugin, allChosenAt: 1).hashCode,
    );
    expect(a, isNot(TranslationPrefs(service: plugin, allChosenAt: 2)));
    expect(a, isNot(TranslationPrefs(service: plugin)));
    expect(a.toString(), contains('allChosenAt: 1'));
    expect(a.copyWith(show: true).allChosenAt, 1);
    expect(a.copyWith(allChosenAt: 7).allChosenAt, 7);
    expect(a.withoutService().allChosenAt, 1);
    expect(a.withTargetLanguage('vi').allChosenAt, 1);
  });

  test('scopePrecedence reads missing or unknown values as replaceAll', () {
    expect(
      decode(<String, Object?>{}).scopePrecedence,
      TranslationScopePrecedence.replaceAll,
    );
    for (final bad in <Object?>['x', 3, null, true]) {
      expect(
        decode(<String, Object?>{'scopePrecedence': bad}).scopePrecedence,
        TranslationScopePrecedence.replaceAll,
      );
    }
  });

  test('scopePrecedence round-trips both values and stays out of extra', () {
    for (final mode in TranslationScopePrecedence.values) {
      final json = encodeTranslationPrefs(
        TranslationPrefs(scopePrecedence: mode),
      );
      expect(json['scopePrecedence'], mode.name);
      final (prefs, extra) = decodeTranslationPrefs(json);
      expect(prefs.scopePrecedence, mode);
      expect(extra.containsKey('scopePrecedence'), isFalse);
    }
  });

  test('scopePrecedence is part of equality, hash and copies', () {
    const keep = TranslationPrefs(
      scopePrecedence: TranslationScopePrecedence.keepCustom,
    );
    expect(keep, isNot(const TranslationPrefs()));
    expect(
      keep.hashCode,
      const TranslationPrefs(
        scopePrecedence: TranslationScopePrecedence.keepCustom,
      ).hashCode,
    );
    expect(keep.toString(), contains('scopePrecedence: keepCustom'));
    expect(keep.copyWith(show: true).scopePrecedence, keep.scopePrecedence);
    expect(
      keep.copyWith(scopePrecedence: TranslationScopePrecedence.replaceAll),
      const TranslationPrefs(),
    );
    expect(keep.withoutService().scopePrecedence, keep.scopePrecedence);
    expect(keep.withTargetLanguage('vi').scopePrecedence, keep.scopePrecedence);
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

  test('a saved DeepL or Google service loads as null with show false', () {
    for (final legacy in ['deepl', 'google']) {
      final prefs = decode(<String, Object?>{
        'show': true,
        'service': legacy,
        'noticeAcknowledged': [legacy],
      });

      expect(prefs.service, isNull, reason: legacy);
      expect(prefs.show, isFalse, reason: legacy);
    }
  });

  test(
    'acknowledged services that are not known are kept, google is dropped',
    () {
      final (prefs, extra) = decodeTranslationPrefs(<String, Object?>{
        'noticeAcknowledged': ['google', 'deepl', 'bing', 7],
      });
      final json = encodeTranslationPrefs(prefs, extra: extra);

      expect(prefs.noticeAcknowledged, isEmpty);
      expect(json['noticeAcknowledged'], ['deepl', 'bing', 7]);
    },
  );

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
        'service': 'google',
        'noticeAcknowledged': ['google'],
      }).show,
      isFalse,
    );
    expect(
      decode(<String, Object?>{
        'show': true,
        'noticeAcknowledged': [plugin.value],
      }).show,
      isFalse,
    );
    expect(
      decode(<String, Object?>{
        'show': true,
        'service': plugin.value,
        'noticeAcknowledged': [plugin.value],
      }).show,
      isTrue,
    );
  });

  test('prefs with the same acknowledged services are equal', () {
    final a = TranslationPrefs(noticeAcknowledged: both);
    final b = TranslationPrefs(noticeAcknowledged: {plugin});

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

    test(
      'a plugin id is kept as the service and as accepted, google dropped',
      () {
        final prefs = decode(<String, Object?>{
          'show': true,
          'service': id.value,
          'noticeAcknowledged': ['google', id.value],
        });

        expect(prefs.service, id);
        expect(prefs.show, isTrue);
        expect(prefs.noticeAcknowledged, {id});
      },
    );

    test('deepl and malformed ids fall back to null, kept in extra, google dropped', () {
      final (prefs, extra) = decodeTranslationPrefs(<String, Object?>{
        'service': 'deepl',
        'noticeAcknowledged': ['deepl', 'plugin-x', 'google', id.value],
      });

      expect(prefs.service, isNull);
      expect(prefs.noticeAcknowledged, {id});
      expect(extra['noticeAcknowledged'], ['deepl', 'plugin-x']);
      final json = encodeTranslationPrefs(prefs, extra: extra);
      expect(json['service'], isNull);
      expect(json['noticeAcknowledged'], [id.value, 'deepl', 'plugin-x']);
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
