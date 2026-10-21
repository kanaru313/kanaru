import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/shared/artist_summaries.dart';

void main() {
  test('one summary per credit, with its counts', () {
    final all = buildArtistSummaries(const [
      ArtistCredit(key: 'ann', name: 'Ann', trackCount: 5, albumCount: 2),
      ArtistCredit(key: 'guest', name: 'Guest', trackCount: 2, albumCount: 0),
    ]);
    expect(all.map((a) => a.key), ['ann', 'guest']);
    expect(all.first.name, 'Ann');
    expect(all.first.songCount, 5);
    expect(all.first.albumCount, 2);
    expect(all.last.albumCount, 0);
  });

  test('the preferred spelling is the smallest, in any order', () {
    expect(preferredSpelling(null, 'Ann'), 'Ann');
    expect(preferredSpelling('Ann', 'ANN'), 'ANN');
    expect(preferredSpelling('ANN', 'Ann'), 'ANN');
  });
}
