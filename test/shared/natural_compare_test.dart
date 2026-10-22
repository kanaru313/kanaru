import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/natural_compare.dart';

void main() {
  List<String> sorted(List<String> names) => [...names]..sort(compareNatural);

  test('numbers compare by value, not digit by digit', () {
    expect(compareNatural('Music 2', 'Music 12'), lessThan(0));
    expect(compareNatural('a1b2', 'a1b10'), lessThan(0));
    expect(sorted(['CD 10', 'CD 2', 'CD 1']), ['CD 1', 'CD 2', 'CD 10']);
  });

  test('numbers of any length do not overflow', () {
    expect(
      compareNatural('99999999999999999999', '100000000000000000000'),
      lessThan(0),
    );
    expect(compareNatural('x${'9' * 60}', 'x1${'0' * 60}'), lessThan(0));
  });

  test('leading zeros: same value, fewer zeros first, then by text', () {
    expect(compareNatural('track 7', 'track 007'), lessThan(0));
    expect(compareNatural('track 007', 'track 8'), lessThan(0));
    expect(compareNatural('track 0', 'track 00'), lessThan(0));
    expect(compareNatural('2', '02'), lessThan(0));
  });

  test('case and accents are ignored, ties break by code point', () {
    expect(compareNatural('Ánh 2', 'anh 10'), lessThan(0));
    expect(compareNatural('Zebra', 'apple'), greaterThan(0));
    expect(compareNatural('a', 'A'), isNot(0));
    expect(compareNatural('a', 'A'), -compareNatural('A', 'a'));
    expect(compareNatural('same', 'same'), 0);
  });

  test('empty, emoji and a number before text', () {
    expect(compareNatural('', 'a'), lessThan(0));
    expect(compareNatural('', ''), 0);
    expect(compareNatural('1', 'a'), lessThan(0));
    expect(compareNatural('😀 2', '😀 10'), lessThan(0));
    expect(compareNatural('a', 'a1'), lessThan(0));
  });

  test('the order is total: shuffles sort to the same list', () {
    final corpus = [
      for (var i = 0; i < 40; i++) ...['Disc $i', 'disc $i', 'Disc 0$i', 'x$i'],
      '',
      'Ánh',
      'anh',
      '😀',
    ];
    final first = sorted([...corpus]..shuffle(Random(1)));
    final second = sorted([...corpus]..shuffle(Random(2)));
    expect(first, second);
    for (var i = 1; i < first.length; i++) {
      expect(compareNatural(first[i - 1], first[i]), lessThanOrEqualTo(0));
      expect(compareNatural(first[i], first[i - 1]), greaterThanOrEqualTo(0));
    }
  });

  group('paths', () {
    test('compare folder by folder, a path that ends first goes first', () {
      expect(compareNaturalPaths('a/1', 'a b/2'), lessThan(0));
      expect(compareNaturalPaths('a b/2', 'a-z/3'), lessThan(0));
      expect(compareNaturalPaths('Album/x', 'Album (Deluxe)/y'), lessThan(0));
      expect(compareNaturalPaths('Album/9', 'Album/10'), lessThan(0));
      expect(compareNaturalPaths('a', 'a/b'), lessThan(0));
      expect(compareNaturalPaths('a/b', 'a/b'), 0);
    });

    List<String> corpus(int n) {
      final rnd = Random(7);
      return [
        for (var i = 0; i < n; i++)
          'Artist ${rnd.nextInt(60)}${rnd.nextBool() ? ' (Deluxe)' : ''}/'
              'Album ${rnd.nextInt(30)}/'
              '${rnd.nextInt(200)} Song ${rnd.nextInt(1000)}.flac',
      ];
    }

    for (final n in [50, naturalSortIsolateThreshold + 1000]) {
      test('sortByNaturalPath orders $n paths like the comparator', () async {
        final names = corpus(n);
        final expected = [...names]..sort(compareNaturalPaths);

        final actual = await sortByNaturalPath(names, (name) => name);

        expect(actual, expected);
      });
    }

    test('sorts items by their path and keeps the input list', () async {
      final items = [(1, 'b/10'), (2, 'b/2'), (3, 'a')];

      final actual = await sortByNaturalPath(items, (item) => item.$2);

      expect([for (final i in actual) i.$1], [3, 2, 1]);
      expect(items.first.$1, 1);
    });
  });
}
