import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/separator_rules.dart';
import 'package:kanaru/shared/genre_summaries.dart';

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
    expect(buildGenreSummaries([(raw: ' ; ', count: 4)]), isEmpty);
  });

  test('custom separators reach the split', () {
    final summaries = buildGenreSummaries([
      (raw: 'Rock/Pop', count: 2),
    ], rules: const SplitRules(separators: ['/'], keepWhole: []));

    expect([for (final g in summaries) g.key], ['pop', 'rock']);
    expect(summaries.first.songCount, 2);
  });
}
