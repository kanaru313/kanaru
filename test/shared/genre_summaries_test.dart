import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/separator_rules.dart';
import 'package:kanaru/shared/genre_summaries.dart';
import 'package:kanaru/shared/library_route_keys.dart';

void main() {
  test('spellings and multi-genre strings merge by key', () {
    final summaries = buildGenreSummaries([
      (raw: 'Rock', count: 1),
      (raw: 'rock', count: 1),
      (raw: 'Rock; Pop', count: 1),
    ]);

    expect([for (final g in summaries) g.key], ['pop', 'rock']);
    final rock = summaries.last;
    expect(rock.name, 'Rock', reason: 'the smallest spelling by code point');
    expect(rock.songCount, 3);
    expect(rock.raws, ['Rock', 'Rock; Pop', 'rock']);
    final pop = summaries.first;
    expect(pop.songCount, 1);
    expect(pop.raws, ['Rock; Pop']);
  });

  test('sorted by key, accents folded', () {
    final summaries = buildGenreSummaries([
      (raw: 'Zydeco', count: 1),
      (raw: 'Ánh', count: 1),
      (raw: 'Blues', count: 1),
    ]);

    expect([for (final g in summaries) g.name], ['Ánh', 'Blues', 'Zydeco']);
  });

  test('nothing in, nothing out', () {
    expect(buildGenreSummaries(const []), isEmpty);
    expect(
      [
        for (final g in buildGenreSummaries([(raw: ' ; ', count: 4)])) g.key,
      ],
      [unknownGenreKey],
      reason: 'a string with no genre in it is the unknown genre',
    );
  });

  test('custom separators reach the split', () {
    final summaries = buildGenreSummaries([
      (raw: 'Rock/Pop', count: 2),
    ], rules: const SplitRules(separators: ['/'], keepWhole: []));

    expect([for (final g in summaries) g.key], ['pop', 'rock']);
    expect(summaries.first.songCount, 2);
  });

  group('unknown genre', () {
    List<String> keys(List<GenreSummary> list) => [for (final g in list) g.key];

    test('tracks with no tag, blanks or only separators gather last', () {
      final summaries = buildGenreSummaries([
        (raw: 'Rock', count: 2),
        (raw: null, count: 3),
        (raw: '   ', count: 1),
        (raw: ';', count: 4),
        (raw: '\u200b', count: 5),
        (raw: '', count: 6),
        (raw: 'Alt', count: 1),
      ]);

      expect(keys(summaries), ['alt', 'rock', unknownGenreKey]);
      final unknown = summaries.last;
      expect(unknown.songCount, 3 + 1 + 4 + 5 + 6);
      expect(unknown.withoutGenre, isTrue);
      expect(unknown.name, isEmpty);
      expect(unknown.raws, ['', '   ', ';', '\u200b']);
      expect(summaries.first.withoutGenre, isFalse);
    });

    test('strings alone, without null, do not reach the null tracks', () {
      final unknown = buildGenreSummaries([(raw: ' ', count: 2)]).single;
      expect(unknown.key, unknownGenreKey);
      expect(unknown.withoutGenre, isFalse);
      expect(unknown.raws, [' ']);
    });

    test('only null still makes the entry; nothing makes none', () {
      final only = buildGenreSummaries([(raw: null, count: 1)]).single;
      expect(only.key, unknownGenreKey);
      expect(only.raws, isEmpty);
      expect(only.withoutGenre, isTrue);
      expect(buildGenreSummaries(const []), isEmpty);
    });

    test('it stays last whatever the other keys sort like', () {
      final summaries = buildGenreSummaries([
        (raw: null, count: 1),
        (raw: '~', count: 1),
        (raw: 'zzz', count: 1),
      ]);
      expect(keys(summaries).last, unknownGenreKey);
    });

    test('the rules decide what is unknown', () {
      final counts = [(raw: '/', count: 1), (raw: 'Rock/Pop', count: 2)];
      expect(keys(buildGenreSummaries(counts)), ['/', 'rock/pop']);

      final custom = buildGenreSummaries(
        counts,
        rules: const SplitRules(separators: ['/'], keepWhole: []),
      );
      expect(keys(custom), ['pop', 'rock', unknownGenreKey]);
      expect(custom.last.raws, ['/']);
    });
  });
}
