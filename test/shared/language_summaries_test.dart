import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/language_summaries.dart';

({String raw, int count, int? durationMs}) _c(
  String raw,
  int count, [
  int? durationMs,
]) => (raw: raw, count: count, durationMs: durationMs);

void main() {
  test('spellings and regions of one language share a row', () {
    final rows = buildLanguageSummaries([
      _c('en', 2, 2000),
      _c('eng', 3, 3000),
      _c('en-US', 1, 1000),
      _c('vie', 4, 4000),
    ]);

    expect([for (final r in rows) r.key], ['eng', 'vie']);
    final eng = rows.first;
    expect(eng.songCount, 6);
    expect(eng.durationMs, 6000);
    expect(eng.name, 'en');
    expect(eng.raws, ['en', 'en-US', 'eng']);
    final vie = rows.last;
    expect(vie.songCount, 4);
    expect(vie.durationMs, 4000);
  });

  test('a string with several languages counts in each', () {
    final rows = buildLanguageSummaries([
      _c('eng; vie', 2, 2000),
      _c('vie', 1, 1000),
    ]);

    expect({for (final r in rows) r.key: r.songCount}, {'eng': 2, 'vie': 3});
    expect({for (final r in rows) r.key: r.durationMs}, {'eng': 2000, 'vie': 3000});
    expect(rows.last.raws, ['eng; vie', 'vie']);
  });

  test('und and empty values get no row, zxx and mul do', () {
    final rows = buildLanguageSummaries([
      _c('und', 5),
      _c(' ; ', 1),
      _c('zxx', 2),
      _c('mul', 1),
      _c('und; fra', 1),
    ]);

    expect(
      {for (final r in rows) r.key: r.songCount},
      {'fra': 1, 'mul': 1, 'zxx': 2},
    );
  });

  test('rows sort by key and nothing gives no rows', () {
    final rows = buildLanguageSummaries([
      _c('x-klingon', 1),
      _c('jpn', 1),
      _c('fr', 1),
    ]);

    expect([for (final r in rows) r.key], ['fra', 'jpn', 'x-klingon']);
    expect(buildLanguageSummaries(const []), isEmpty);
  });
}
