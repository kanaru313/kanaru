import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/lyrics_translation/translation_cache.dart';
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

    test('keeps the settings snapshot of the row', () {
      final row = LyricTranslationRow(
        contentHash: 'h',
        provider: _plugin.value,
        targetLang: 'vi',
        sourceLang: 'en',
        linesJson: '{"hi":"chào"}',
        settingsJson: '{"model":"pro"}',
        createdAt: 1,
      );
      expect(decodeTranslationRow(row)!.settingsJson, '{"model":"pro"}');
      expect(
        decodeTranslationRow(_row(_plugin.value, '{"hi":"chào"}'))!
            .settingsJson,
        isNull,
      );
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

    test('offers a known plugin row, skips an id with no record', () {
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
        pickCached([unknown], _plugin, knownPlugins: {_otherPlugin}).other,
        isNull,
      );
    });

    CachedTranslation sameRowOf(TranslationServiceId s) => CachedTranslation(
      service: s,
      targetLang: 'vi',
      sourceLang: 'vi',
      lines: const {},
    );

    test('another service same-language row loses to one with lines', () {
      final sameRow = sameRowOf(_otherPlugin);
      final withLines = _cached(_removed);
      final r = pickCached(
        [sameRow, withLines],
        _plugin,
        knownPlugins: {_otherPlugin, _removed},
        livePlugins: {_otherPlugin},
      );
      expect(r.other, same(withLines));
    });

    test('a removed plugin same-language row is not a fallback', () {
      final r = pickCached(
        [sameRowOf(_otherPlugin)],
        _plugin,
        knownPlugins: {_otherPlugin},
      );
      expect(r.other, isNull);
    });

    test('a live plugin same-language row is a fallback', () {
      final sameRow = sameRowOf(_otherPlugin);
      final r = pickCached(
        [sameRow],
        _plugin,
        knownPlugins: {_otherPlugin},
        livePlugins: {_otherPlugin},
      );
      expect(r.other, same(sameRow));
    });

    test('the selected service same-language row is current', () {
      final sameRow = sameRowOf(_otherPlugin);
      expect(
        pickCached(
          [sameRow],
          _otherPlugin,
          knownPlugins: {_otherPlugin},
        ).current,
        same(sameRow),
      );
    });
  });
}
