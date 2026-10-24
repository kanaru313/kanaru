import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/artist_names.dart';
import 'package:kanaru/core/database/text_key_tables.dart';
import 'package:kanaru/core/database/text_keys.dart';

/// Hangul "한" as jamo (what macOS writes) and as one syllable.
const _hanJamo = '한';
const _hanSyllable = '한';

/// Names the keys must treat the same however the tag was written.
const _corpus = [
  'Beyonce\u0301',
  'Beyonc\u00e9',
  'Nguye\u0302\u0303n',
  '\u0110en V\u00e2u',
  'J\u030c',
  '\u0130stanbul',
  '\u03a3\u039f\u03a6\u039f\u03a3',
  'Stra\u00dfe',
  '\u00d8lsen',
  '\u00c6on',
  'A\u0000b',
  '\u200bName\u200e',
  '\u304b\u3099',
  _hanJamo,
  '\u65e5\u672c\u8a9e',
  '\u{1F600} Fun',
];

void main() {
  group('groupKey', () {
    test('lower cases and keeps accents', () {
      expect(groupKey('The Beatles'), 'the beatles');
      expect(groupKey('ÁNH'), 'ánh');
      expect(groupKey('Đen Vâu'), 'đen vâu');
      expect(groupKey('Anh'), isNot(groupKey('Ánh')));
      expect(groupKey('Ølsen'), 'ølsen');
    });

    test('decomposed and composed spellings are one key', () {
      expect(groupKey('Beyoncé'), groupKey('Beyoncé'));
      expect(groupKey('Beyoncé'), 'beyoncé');
      expect(groupKey('Ánh'), 'ánh');
      // Vietnamese: base + dot below + circumflex, either mark order.
      expect(groupKey('Nguyễn'), 'nguyễn');
      expect(groupKey('Hoậ'), 'hoậ'.replaceAll('ậ', 'ậ'));
      expect(groupKey('ậ'), 'ậ');
      expect(groupKey('ậ'), 'ậ');
      expect(groupKey('ậ'), 'ậ');
      expect(groupKey('ậ'), 'ậ');
      expect(groupKey('ậ'), 'ậ');
    });

    test('composes Greek, Cyrillic, kana and Hangul', () {
      expect(groupKey('й'), 'й'); // й
      expect(groupKey('ё'), 'ё'); // ё
      expect(groupKey('ά'), 'ά'); // ά
      expect(groupKey('が'), 'が'); // が
      expect(groupKey(_hanJamo), _hanSyllable);
      expect(groupKey('하'), '하');
    });

    test('marks with nothing to join stay', () {
      expect(groupKey('x́'), 'x́');
      expect(groupKey('́a'), '́a');
      // Two marks of the same class do not both attach.
      expect(groupKey('á́'), 'á́');
    });

    test('keeps CJK and emoji, replaces control characters by spaces', () {
      expect(groupKey('日本語'), '日本語');
      expect(groupKey('😀 Fun'), '😀 fun');
      expect(groupKey('A\u0000B\tC\u007f'), 'a b c ');
      expect(groupKey('Ti\u001ftle'), 'ti tle');
    });

    test('cuts to 256 characters without splitting one', () {
      expect(groupKey('😀' * 300).runes.length, maxKeyLength);
      expect(groupKey('a' * 300).length, maxKeyLength);
      expect(groupKey('é' * 300).runes.length, maxKeyLength);
      // The cut is after normalizing, so spellings agree.
      expect(groupKey('é' * 300), groupKey('é' * 300));
    });

    test('upper case and decomposed spellings of one letter agree', () {
      const pairs = [
        ['J\u030c', '\u01f0'], // ǰ
        ['H\u0331', '\u1e96'], // ẖ
        ['\u0130', 'I\u0307'], // İ
        ['\u0130', 'i\u0307'],
      ];
      for (final [a, b] in pairs) {
        expect(groupKey(a), groupKey(b), reason: '$a $b');
      }
      expect(splitArtists('J\u030c; \u01f0'), hasLength(1));
    });

    test('is idempotent over the corpus', () {
      for (final text in _corpus) {
        expect(groupKey(groupKey(text)), groupKey(text), reason: text);
      }
    });

    test('Greek final sigma and sigma are one letter', () {
      expect(
        groupKey('\u03a3\u039f\u03a6\u039f\u03a3'),
        groupKey('\u03c3\u03bf\u03c6\u03bf\u03c2'),
      );
      expect(groupKey('\u03c2'), '\u03c3');
    });

    test('invisible format characters never make another name', () {
      expect(groupKey('Name\u200e'), groupKey('Name'));
      expect(groupKey('\ufeffName'), 'name');
      expect(groupKey('Na\u200bme\u2060'), 'name');
      expect(groupKey('\u202aName\u202c'), 'name');
    });
    test('is idempotent', () {
      for (final text in ['Beyoncé', 'Đen', 'Straße', 'A\u0000b', '한']) {
        expect(groupKey(groupKey(text)), groupKey(text), reason: text);
      }
    });
  });

  test('every table entry recomposes from its parts and folds to its base', () {
    for (var i = 0; i < decompositionTriples.length; i += 3) {
      final whole = String.fromCharCode(decompositionTriples[i]);
      final parts = String.fromCharCodes([
        decompositionTriples[i + 1],
        decompositionTriples[i + 2],
      ]);
      expect(groupKey(parts), groupKey(whole), reason: whole);
      expect(sortKey(whole), sortKey(parts), reason: whole);
    }
  });

  group('sortKey', () {
    test('drops accents but keeps the letters apart from other letters', () {
      expect(sortKey('Ánh'), 'anh');
      expect(sortKey('Anh'), 'anh');
      expect(sortKey('Beyoncé'), 'beyonce');
      expect(sortKey('Beyoncé'), 'beyonce');
      expect(sortKey('Nguyễn'), 'nguyen');
      expect(sortKey('Hoặc'), 'hoac');
      expect(sortKey('Bạn Ơi'), 'ban oi');
    });

    test('Ánh and Anh are adjacent, and different group keys', () {
      final names = ['Ánh', 'Anh', 'Ban', 'An', 'Ao', 'Ách'];
      names.sort((a, b) => sortKey(a).compareTo(sortKey(b)));
      expect(names.take(3), containsAll(['An', 'Ách']));
      final i = names.indexOf('Ánh');
      final j = names.indexOf('Anh');
      expect((i - j).abs(), 1);
      expect(groupKey('Ánh'), isNot(groupKey('Anh')));
    });

    test('folds letters without a decomposition', () {
      const table = {
        'Đen Vâu': 'den vau',
        'đ': 'd',
        'Ðorđe': 'dorde',
        'Ølsen': 'olsen',
        'Łódź': 'lodz',
        'Straße': 'strasse',
        'Æon': 'aeon',
        'Œuvre': 'oeuvre',
        'Þór': 'thor',
        'ı': 'i',
        'İstanbul': 'istanbul',
        'Ǿ': 'o',
        'ǣ': 'ae',
      };
      for (final MapEntry(:key, :value) in table.entries) {
        expect(sortKey(key), value, reason: key);
      }
    });

    test('Đen Vâu sorts under d, between Dạ and E', () {
      final names = ['Eminem', 'Đen Vâu', 'Dạ', 'Dua Lipa', 'Cher'];
      names.sort((a, b) => sortKey(a).compareTo(sortKey(b)));
      expect(names, ['Cher', 'Dạ', 'Đen Vâu', 'Dua Lipa', 'Eminem']);
    });

    test('keeps articles, trims, and handles the ASCII path', () {
      expect(sortKey('The Beatles'), 'the beatles');
      expect(sortKey('  Hello World '), 'hello world');
      expect(sortKey('ABC'), 'abc');
      expect(sortKey(''), '');
      expect(sortKey('A\u0000B'), 'a b');
    });

    test('keeps CJK and emoji by code point, folds fullwidth ASCII', () {
      expect(sortKey('日本語'), '日本語');
      expect(sortKey('😀 Fun'), '😀 fun');
      expect(sortKey('ＡＢＣ　１２３'), 'abc 123');
      expect(sortKey('が'), 'か'); // が sorts with か
      expect(sortKey('が'), 'か');
    });

    test('decomposed and composed Hangul sort alike', () {
      expect(sortKey(_hanJamo), _hanSyllable);
      expect(sortKey(_hanSyllable), _hanSyllable);
    });

    test('Greek final sigma, invisible characters and cut edges', () {
      expect(
        sortKey('\u03a3\u039f\u03a6\u039f\u03a3'),
        sortKey('\u03c3\u03bf\u03c6\u03bf\u03c2'),
      );
      expect(sortKey('\u200bZed'), 'zed');
      expect(sortKey('\ufeff\u00c1nh\u200e'), 'anh');
      // A cut never leaves a trailing space.
      expect(sortKey('${'a' * 255} b'), 'a' * 255);
      expect(sortKey('${'\u00e1' * 255} b'), 'a' * 255);
    });

    test('cuts to 256 characters', () {
      expect(sortKey('É' * 300).length, maxKeyLength);
      expect(sortKey('😀' * 300).runes.length, maxKeyLength);
    });
  });

  group('artistSortKey', () {
    test('drops a leading "the " only when something follows', () {
      expect(artistSortKey('The Beatles'), 'beatles');
      expect(artistSortKey('the  beatles'), 'beatles');
      expect(artistSortKey('THE BEATLES'), 'beatles');
      expect(artistSortKey('The'), 'the');
      expect(artistSortKey('The '), 'the');
      expect(artistSortKey('Theory of a Deadman'), 'theory of a deadman');
      expect(artistSortKey('Thelonious Monk'), 'thelonious monk');
      expect(artistSortKey('Đen'), 'den');
      expect(artistSortKey('The Ánh'), 'anh');
    });

    test('only the first article goes', () {
      expect(artistSortKey('The The'), 'the');
      expect(artistSortKey('The The Band'), 'the band');
    });
  });

  test('text keys version covers the search columns', () {
    expect(textKeysVersion, 3);
  });

  test('keys 100k mixed names fast enough for a background backfill', () {
    final names = [
      'The Beatles',
      'Nguyễn Văn A',
      'Beyoncé',
      'Plain Ascii Name',
      'Đen Vâu feat. Linh Cáo',
    ];
    final watch = Stopwatch()..start();
    var length = 0;
    for (var i = 0; i < 100000; i++) {
      final name = names[i % names.length];
      length += groupKey(name).length + artistSortKey(name).length;
    }
    expect(length, greaterThan(0));
    expect(watch.elapsedMilliseconds, lessThan(5000));
  });

  // Pins the output of the rules, including Dart's `toLowerCase`: an SDK
  // upgrade that changes these fails here, and textKeysVersion must go up.
  test('keys of a fixed corpus match the recorded output', () {
    const golden = {
      'The Beatles': ['the beatles', 'the beatles', 'beatles'],
      'Beyonce\u0301': ['beyonc\u00e9', 'beyonce', 'beyonce'],
      '\u0110en V\u00e2u': ['\u0111en v\u00e2u', 'den vau', 'den vau'],
      'Nguye\u0302\u0303n': ['nguy\u1ec5n', 'nguyen', 'nguyen'],
      'S\u01a1n T\u00f9ng M-TP': [
        's\u01a1n t\u00f9ng m-tp',
        'son tung m-tp',
        'son tung m-tp',
      ],
      '\u0110\u1eebng L\u00e0m': [
        '\u0111\u1eebng l\u00e0m',
        'dung lam',
        'dung lam',
      ],
      '\u00d8lsen': ['\u00f8lsen', 'olsen', 'olsen'],
      'Stra\u00dfe': ['stra\u00dfe', 'strasse', 'strasse'],
      '\u00c6on': ['\u00e6on', 'aeon', 'aeon'],
      '\u0141\u00f3d\u017a': ['\u0142\u00f3d\u017a', 'lodz', 'lodz'],
      '\u03a3\u039f\u03a6\u039f\u03a3': [
        '\u03c3\u03bf\u03c6\u03bf\u03c3',
        '\u03c3\u03bf\u03c6\u03bf\u03c3',
        '\u03c3\u03bf\u03c6\u03bf\u03c3',
      ],
      '\u0130stanbul': ['istanbul', 'istanbul', 'istanbul'],
      '\u65e5\u672c\u8a9e': [
        '\u65e5\u672c\u8a9e',
        '\u65e5\u672c\u8a9e',
        '\u65e5\u672c\u8a9e',
      ],
    };
    for (final MapEntry(:key, :value) in golden.entries) {
      expect(
        [groupKey(key), sortKey(key), artistSortKey(key)],
        value,
        reason: key,
      );
    }
  });
}
