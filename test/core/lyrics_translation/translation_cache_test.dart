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
final _otherPlugin = TranslationServiceId.tryParse('plugin-111111111111')!;
final _removed = TranslationServiceId.tryParse('plugin-zzzzzzzzzzzz')!;

void main() {
  group('decodeTranslationRow', () {
    test('decodes a valid row', () {
      final c = decodeTranslationRow(_row(_plugin.value, '{"hi":"chào"}'))!;
      expect(c.service, _plugin);
      expect(c.targetLang, 'vi');
      expect(c.sourceLang, 'en');
      expect(c.lines, {'hi': 'chào'});
    });

    test('bad JSON gives null', () {
      expect(decodeTranslationRow(_row(_plugin.value, '{oops')), isNull);
    });

    test('non-object and non-string values give null', () {
      expect(decodeTranslationRow(_row(_plugin.value, '["a"]')), isNull);
      expect(decodeTranslationRow(_row(_plugin.value, '{"a":1}')), isNull);
    });

    test('unknown provider gives null', () {
      expect(decodeTranslationRow(_row('bing', '{}')), isNull);
    });

    test('a plugin id row decodes', () {
      final c = decodeTranslationRow(_row(_plugin.value, '{"a":"b"}'))!;
      expect(c.service, _plugin);
    });

    test('a row saved by the removed Google or DeepL client gives null', () {
      expect(decodeTranslationRow(_row('google', '{"hi":"chào"}')), isNull);
      expect(decodeTranslationRow(_row('deepl', '{"hi":"chào"}')), isNull);
    });
  });

  test('decoded lines cannot be modified', () {
    final c = decodeTranslationRow(_row(_plugin.value, '{"a":"b"}'))!;
    expect(() => c.lines['x'] = 'y', throwsUnsupportedError);
  });

  test('encode then decode round-trips', () {
    final json = encodeTranslationLines({'a': 'b', 'c': 'd'});
    expect(decodeTranslationRow(_row(_plugin.value, json))!.lines, {
      'a': 'b',
      'c': 'd',
    });
  });

  group('pickCached', () {
    final preferred = _cached(_plugin);

    test('prefers the current service', () {
      final r = pickCached([preferred], _plugin);
      expect(r.current, same(preferred));
      expect(r.other, isNull);
    });

    test('empty list gives nothing', () {
      final r = pickCached([], _plugin);
      expect((r.current, r.other), (null, null));
    });

    test(
      'offers a known plugin row, skips an id with no record',
      () {
        final other = _cached(_otherPlugin);
        final unknown = _cached(_removed);
        expect(
          pickCached(
            [unknown, other],
            _plugin,
            knownPlugins: {_otherPlugin},
          ).other,
          same(other),
        );
        expect(
          pickCached(
            [unknown],
            _plugin,
            knownPlugins: {_otherPlugin},
          ).other,
          isNull,
        );
      },
    );

    test('never offers a same-language row of another service', () {
      final sameRow = CachedTranslation(
        service: _otherPlugin,
        targetLang: 'vi',
        sourceLang: 'vi',
        lines: const {},
      );
      final vi = translationLanguageFor('vi')!;

      final r = pickCached(
        [sameRow],
        _plugin,
        knownPlugins: {_otherPlugin},
        target: vi,
      );

      expect(r.other, isNull);
      expect(
        pickCached(
          [sameRow],
          _otherPlugin,
          knownPlugins: {_otherPlugin},
          target: vi,
        ).current,
        same(sameRow),
      );
    });
  });
}
