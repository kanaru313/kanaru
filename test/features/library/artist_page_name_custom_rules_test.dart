import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/library/artists/artist_page_sections.dart';

var _id = 0;

BrowseTrack _track(String artist) =>
    BrowseTrack(id: _id++, path: '/t$_id', title: 'T$_id', artist: artist);

String _name(String key, List<String> tags) => ArtistPageSections.fromTracks(
  key,
  [for (final tag in tags) _track(tag)],
  const [],
).name;

void main() {
  // The page does not know the split rules: tracks keyed with custom ones
  // still get the spelling written in the tag.
  test('a name joined by a custom separator keeps its capitals', () {
    expect(_name('ann', ['Ann | Bob']), 'Ann');
    expect(_name('bob', ['Ann | Bob']), 'Bob');
    expect(_name('bob', ['Ann & BOB']), 'BOB');
  });

  test('the default split still decides when it gives the key', () {
    expect(_name('ann', ['Ann; Bob']), 'Ann');
  });

  test('only a stretch that stands alone counts', () {
    // "ann" is inside "Joanna" but not a name of its own there.
    expect(_name('ann', ['Joanna | Ann']), 'Ann');
    expect(_name('ann', ['Joanna']), 'ann', reason: 'falls back on the key');
  });

  test('the spelling is chosen among the tracks like in the list', () {
    expect(_name('ann', ['ann & Bob', 'ANN | Cy']), 'ANN');
  });

  test('no artist tag, empty key', () {
    expect(
      ArtistPageSections.fromTracks('x', [
        const BrowseTrack(id: 1, path: '/p', title: 'T'),
      ], const []).name,
      'x',
    );
  });
}
