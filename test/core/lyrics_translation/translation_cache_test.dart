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

CachedTranslation _cached(LyricsTranslationService s) => CachedTranslation(
  service: s,
  targetLang: 'vi',
  sourceLang: 'en',
  lines: const {},
);

void main() {
  group('decodeTranslationRow', () {
    test('decodes a valid row', () {
      final c = decodeTranslationRow(_row('deepl', '{"hi":"chào"}'))!;
      expect(c.service, LyricsTranslationService.deepl);
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
    final google = _cached(LyricsTranslationService.google);
    final deepl = _cached(LyricsTranslationService.deepl);

    test('prefers the current service', () {
      final r = pickCached([google, deepl], LyricsTranslationService.deepl);
      expect(r.current, same(deepl));
      expect(r.other, same(google));
    });

    test('falls back to the other service', () {
      final r = pickCached([google], LyricsTranslationService.deepl);
      expect(r.current, isNull);
      expect(r.other, same(google));
    });

    test('empty list gives nothing', () {
      final r = pickCached([], LyricsTranslationService.google);
      expect((r.current, r.other), (null, null));
    });
  });
}
