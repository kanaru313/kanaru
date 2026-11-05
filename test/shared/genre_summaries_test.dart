import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/separator_rules.dart';
import 'package:kanaru/shared/genre_summaries.dart';
import 'package:kanaru/shared/library_route_keys.dart';

({String? raw, int count, int? durationMs}) _c(
  String? raw,
  int count, [
  int? durationMs,
]) => (raw: raw, count: count, durationMs: durationMs);

void main() {
  test('spellings and multi-genre strings merge by key', () {
    final summaries = buildGenreSummaries([
      _c('Rock', 1, 1000),
      _c('rock', 1, 2000),
      _c('Rock; Pop', 1, 3000),
    ]);

    expect([for (final g in summaries) g.key], ['pop', 'rock']);
    final rock = summaries.last;
    expect(rock.name, 'Rock', reason: 'the smallest spelling by code point');
    expect(rock.songCount, 3);
    expect(rock.durationMs, 6000);
    expect(rock.raws, ['Rock', 'Rock; Pop', 'rock']);
    final pop = summaries.first;
    expect(pop.songCount, 1);
    expect(pop.durationMs, 3000);
    expect(pop.raws, ['Rock; Pop']);
  });

  test('sorted by key, accents folded', () {
    final summaries = buildGenreSummaries([
      _c('Zydeco', 1),
      _c('Ánh', 1),
      _c('Blues', 1),
    ]);

    expect([for (final g in summaries) g.name], ['Ánh', 'Blues', 'Zydeco']);
  });

  test('nothing in, nothing out', () {
    expect(buildGenreSummaries(const []), isEmpty);
    expect(
      [
        for (final g in buildGenreSummaries([_c(' ; ', 4)])) g.key,
      ],
      [unknownGenreKey],
      reason: 'a string with no genre in it is the unknown genre',
    );
  });

  test('custom separators reach the split', () {
    final summaries = buildGenreSummaries([
      _c('Rock/Pop', 2, 4000),
    ], rules: const SplitRules(separators: ['/'], keepWhole: []));

    expect([for (final g in summaries) g.key], ['pop', 'rock']);
    expect(summaries.first.songCount, 2);
    expect(summaries.first.durationMs, 4000);
  });

  group('unknown genre', () {
    List<String> keys(List<GenreSummary> list) => [for (final g in list) g.key];

    test('tracks with no tag, blanks or only separators gather last', () {
      final summaries = buildGenreSummaries([
        _c('Rock', 2),
        _c(null, 3),
        _c('   ', 1),
        _c(';', 4),
        _c('\u200b', 5),
        _c('', 6),
        _c('Alt', 1),
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
      final unknown = buildGenreSummaries([_c(' ', 2, 5000)]).single;
      expect(unknown.key, unknownGenreKey);
      expect(unknown.withoutGenre, isFalse);
      expect(unknown.durationMs, 5000);
      expect(unknown.raws, [' ']);
    });

    test('only null still makes the entry; nothing makes none', () {
      final only = buildGenreSummaries([_c(null, 1)]).single;
      expect(only.key, unknownGenreKey);
      expect(only.raws, isEmpty);
      expect(only.withoutGenre, isTrue);
      expect(buildGenreSummaries(const []), isEmpty);
    });

    test('it stays last whatever the other keys sort like', () {
      final summaries = buildGenreSummaries([
        _c(null, 1),
        _c('~', 1),
        _c('zzz', 1),
      ]);
      expect(keys(summaries).last, unknownGenreKey);
    });

    test('the rules decide what is unknown', () {
      final counts = [_c('/', 1), _c('Rock/Pop', 2)];
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
