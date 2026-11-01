import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/lyrics_translation/translation_cache.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';

LyricTranslationRow _row(String provider, String json) => LyricTranslationRow(
  contentHash: 'h',
  provider: provider,
  targetLang: 'vi',
  sourceLang: 'en',
  linesJson: json,
  createdAt: 1,
);

CachedTranslation _cached(TranslationServiceId s) => CachedTranslation(
  service: s,
  targetLang: 'vi',
  sourceLang: 'en',
  lines: const {},
);

final _plugin = TranslationServiceId.tryParse('plugin-abc123def456')!;
final _removed = TranslationServiceId.tryParse('plugin-zzzzzzzzzzzz')!;

void main() {
  group('decodeTranslationRow', () {
    test('decodes a valid row', () {
      final c = decodeTranslationRow(_row('google', '{"hi":"chào"}'))!;
      expect(c.service, TranslationServiceId.google);
      expect(c.targetLang, 'vi');
      expect(c.sourceLang, 'en');
      expect(c.lines, {'hi': 'chào'});
    });

    test('bad JSON gives null', () {
      expect(decodeTranslationRow(_row('google', '{oops')), isNull);
    });

    test('non-object and non-string values give null', () {
      expect(decodeTranslationRow(_row('google', '["a"]')), isNull);
      expect(decodeTranslationRow(_row('google', '{"a":1}')), isNull);
    });

    test('unknown provider gives null', () {
      expect(decodeTranslationRow(_row('bing', '{}')), isNull);
    });

    test('a plugin id row decodes', () {
      final c = decodeTranslationRow(_row(_plugin.value, '{"a":"b"}'))!;
      expect(c.service, _plugin);
    });

    test('a row saved by the removed DeepL client gives null', () {
      expect(decodeTranslationRow(_row('deepl', '{"hi":"chào"}')), isNull);
    });
  });

  test('decoded lines cannot be modified', () {
    final c = decodeTranslationRow(_row('google', '{"a":"b"}'))!;
    expect(() => c.lines['x'] = 'y', throwsUnsupportedError);
  });

  test('encode then decode round-trips', () {
    final json = encodeTranslationLines({'a': 'b', 'c': 'd'});
    expect(decodeTranslationRow(_row('google', json))!.lines, {
      'a': 'b',
      'c': 'd',
    });
  });

  group('pickCached', () {
    final google = _cached(TranslationServiceId.google);

    test('prefers the current service', () {
      final r = pickCached([google], TranslationServiceId.google);
      expect(r.current, same(google));
      expect(r.other, isNull);
    });

    test('empty list gives nothing', () {
      final r = pickCached([], TranslationServiceId.google);
      expect((r.current, r.other), (null, null));
    });

    test(
      'offers a known plugin row and Google, skips an id with no record',
      () {
        final plugin = _cached(_plugin);
        final unknown = _cached(_removed);
        expect(
          pickCached(
            [unknown, plugin],
            TranslationServiceId.google,
            knownPlugins: {_plugin},
          ).other,
          same(plugin),
        );
        expect(
          pickCached(
            [unknown],
            TranslationServiceId.google,
            knownPlugins: {_plugin},
          ).other,
          isNull,
        );
        expect(pickCached([google], _plugin).other, same(google));
      },
    );

    test('never offers a same-language row of another service', () {
      final sameRow = CachedTranslation(
        service: _plugin,
        targetLang: 'vi',
        sourceLang: 'vi',
        lines: const {},
      );
      final vi = translationLanguageFor('vi')!;

      final r = pickCached(
        [sameRow],
        TranslationServiceId.google,
        knownPlugins: {_plugin},
        target: vi,
      );

      expect(r.other, isNull);
      expect(
        pickCached(
          [sameRow],
          _plugin,
          knownPlugins: {_plugin},
          target: vi,
        ).current,
        same(sameRow),
      );
    });
  });
}
