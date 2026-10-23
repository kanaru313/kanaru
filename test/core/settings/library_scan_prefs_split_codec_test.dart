import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/library_scan_prefs.dart';
import 'package:kanaru/core/settings/library_scan_prefs_codec.dart';

SplitPrefs decodeArtist(Object? value) =>
    decodeLibraryScanPrefs({'artistSplit': value}).$1.artistSplit;

void main() {
  test('defaults are the agreed ones', () {
    const d = LibraryScanPrefs();
    expect(d.artistSplit.separators, [
      ';',
      '/',
      'feat.',
      'feat',
      'ft.',
      'ft',
      'featuring',
      'with',
    ]);
    expect(d.artistSplit.keepWhole, ['AC/DC']);
    expect(d.genreSplit.separators, [';']);
    expect(d.genreSplit.keepWhole, isEmpty);
    expect(decodeLibraryScanPrefs(null).$1, d);
    expect(decodeLibraryScanPrefs(const {}).$1, d);
  });

  test('values round-trip, an empty list stays empty', () {
    const prefs = LibraryScanPrefs(
      artistSplit: SplitPrefs(separators: ['|', 'and'], keepWhole: ['A|B']),
      genreSplit: SplitPrefs(separators: [], keepWhole: []),
    );
    final json = encodeLibraryScanPrefs(prefs);
    expect(json['artistSplit'], {
      'separators': ['|', 'and'],
      'keepWhole': ['A|B'],
    });
    expect(json['genreSplit'], {'separators': <String>[], 'keepWhole': []});
    expect(decodeLibraryScanPrefs(json).$1, prefs);
  });

  test('a value that is not an object, or lists that are not lists', () {
    for (final bad in <Object?>['x', 1, null, true, 1.5, <Object?>{}]) {
      expect(decodeArtist(bad), defaultArtistSplit, reason: '$bad');
      expect(
        decodeArtist({'separators': bad, 'keepWhole': bad}),
        defaultArtistSplit,
        reason: '$bad',
      );
    }
  });

  test('each list falls back on its own', () {
    final split = decodeArtist({
      'separators': 'no',
      'keepWhole': ['X/Y'],
    });
    expect(split.separators, defaultArtistSeparators);
    expect(split.keepWhole, ['X/Y']);
  });

  test('items that are not strings are skipped', () {
    final split = decodeArtist({
      'separators': [1, null, '|', true, <Object?>[], 'and'],
    });
    expect(split.separators, ['|', 'and']);
  });

  test('control characters go, whitespace is trimmed, blanks are dropped', () {
    final split = decodeArtist({
      'separators': [' | ', '\t', '', '  ', 'a\u0000nd\n', '\u007f;'],
    });
    expect(split.separators, ['|', 'and', ';']);
  });

  test('repeats in any case are dropped, the first one stays', () {
    final split = decodeArtist({
      'separators': ['And', 'and', 'AND', '|', '|'],
    });
    expect(split.separators, ['And', '|']);
  });

  test('an entry over 64 characters is dropped, 64 is kept', () {
    final ok = 'a' * 64;
    final split = decodeArtist({
      'separators': ['${ok}b', ok, 'x'],
    });
    expect(split.separators, [ok, 'x']);
  });

  test('length counts characters, not code units', () {
    final emoji = '😀' * 64;
    final split = decodeArtist({
      'separators': [emoji, '$emoji😀'],
    });
    expect(split.separators, [emoji]);
  });

  test('at most 64 entries are kept, the first ones', () {
    final split = decodeArtist({
      'separators': [for (var i = 0; i < 100; i++) 's$i'],
    });
    expect(split.separators.length, 64);
    expect(split.separators.first, 's0');
    expect(split.separators.last, 's63');
  });

  test('unknown keys ride along, inside the split objects too', () {
    final (prefs, extra) = decodeLibraryScanPrefs({
      'artistSplit': {
        'separators': ['|'],
        'future': 1,
      },
      'genreSplit': {'keepWhole': [], 'other': 'x'},
      'unknownTop': 2,
    });
    expect(extra, {
      'unknownTop': 2,
      'artistSplit': {'future': 1},
      'genreSplit': {'other': 'x'},
    });
    final json = encodeLibraryScanPrefs(prefs, extra: extra);
    expect(json['unknownTop'], 2);
    expect((json['artistSplit']! as Map)['future'], 1);
    expect((json['artistSplit']! as Map)['separators'], ['|']);
    expect((json['genreSplit']! as Map)['other'], 'x');
  });

  test('copyWith, equality and hashCode follow the lists', () {
    const a = SplitPrefs(separators: ['|'], keepWhole: ['x']);
    const b = SplitPrefs(separators: ['|'], keepWhole: ['x']);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.copyWith(keepWhole: []), isNot(a));
    expect(a.copyWith(separators: ['#']).keepWhole, ['x']);
    const p = LibraryScanPrefs();
    expect(p.copyWith(artistSplit: a).artistSplit, a);
    expect(p.copyWith(genreSplit: a).genreSplit, a);
    expect(p.copyWith(genreSplit: a), isNot(p));
  });
}
