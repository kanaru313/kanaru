import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/language_summaries.dart';

void main() {
  test('spellings and regions of one language share a row', () {
    final rows = buildLanguageSummaries([
      (raw: 'en', count: 2),
      (raw: 'eng', count: 3),
      (raw: 'en-US', count: 1),
      (raw: 'vie', count: 4),
    ]);

    expect([for (final r in rows) r.key], ['eng', 'vie']);
    final eng = rows.first;
    expect(eng.songCount, 6);
    expect(eng.name, 'en');
    expect(eng.raws, ['en', 'en-US', 'eng']);
  });

  test('a string with several languages counts in each', () {
    final rows = buildLanguageSummaries([
      (raw: 'eng; vie', count: 2),
      (raw: 'vie', count: 1),
    ]);

    expect({for (final r in rows) r.key: r.songCount}, {'eng': 2, 'vie': 3});
    expect(rows.last.raws, ['eng; vie', 'vie']);
  });

  test('und and empty values get no row, zxx and mul do', () {
    final rows = buildLanguageSummaries([
      (raw: 'und', count: 5),
      (raw: ' ; ', count: 1),
      (raw: 'zxx', count: 2),
      (raw: 'mul', count: 1),
      (raw: 'und; fra', count: 1),
    ]);

    expect(
      {for (final r in rows) r.key: r.songCount},
      {'fra': 1, 'mul': 1, 'zxx': 2},
    );
  });

  test('rows sort by key and nothing gives no rows', () {
    final rows = buildLanguageSummaries([
      (raw: 'x-klingon', count: 1),
      (raw: 'jpn', count: 1),
      (raw: 'fr', count: 1),
    ]);

    expect([for (final r in rows) r.key], ['fra', 'jpn', 'x-klingon']);
    expect(buildLanguageSummaries(const []), isEmpty);
  });
}
