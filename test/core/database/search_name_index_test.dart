import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_rows.dart';
import 'package:kanaru/core/database/search_name_index.dart';
import 'package:kanaru/core/database/search_terms.dart';

AlbumSummary _album(String title, {String? artist, int tracks = 1}) =>
    AlbumSummary(
      key: AlbumKey(artist ?? '', title.toLowerCase()),
      title: title,
      artist: artist,
      trackCount: tracks,
      addedAt: 0,
    );

ArtistCredit _artist(String name, {int tracks = 1}) => ArtistCredit(
  key: name.toLowerCase(),
  name: name,
  trackCount: tracks,
  albumCount: 1,
);

List<String> _titles(List<AlbumSummary> albums) => [
  for (final a in albums) a.title,
];

void main() {
  test('albums match on title and album artist', () {
    final index = albumSearchIndex([
      _album('Sky Walker', artist: 'Sơn Tùng'),
      _album('Other', artist: 'Someone'),
    ]);
    expect(_titles(index.match(searchTerms('tung'))), ['Sky Walker']);
    expect(_titles(index.match(searchTerms('walk son'))), ['Sky Walker']);
    expect(_titles(index.match(searchTerms('other'))), ['Other']);
  });

  test('a merged album matches every artist given for it', () {
    final merged = AlbumSummary(
      key: const AlbumKey('', 'hits'),
      title: 'Hits',
      artist: 'ABBA',
      trackCount: 3,
      addedAt: 0,
      variousArtists: true,
    );
    final names = {
      merged.key: ['ABBA', 'Madonna', 'Queen'],
    };
    final index = albumSearchIndex([merged], artistNames: names);
    expect(_titles(index.match(searchTerms('madonna'))), ['Hits']);
    expect(
      _titles(albumSearchIndex([merged]).match(searchTerms('madonna'))),
      isEmpty,
    );
    expect(_titles(index.match(searchTerms('hits queen'))), ['Hits']);
  });

  test('words past the eighth of a long album title are searchable', () {
    final index = albumSearchIndex([
      _album(
        'The Rise and Fall of Ziggy Stardust and the Spiders from Mars',
        artist: 'David Bowie',
      ),
    ]);
    expect(index.match(searchTerms('mars')), hasLength(1));
    expect(index.match(searchTerms('bowie')), hasLength(1));
  });

  test('artists match their own name only', () {
    // One track credited "Sơn Tùng; Bích Phương" yields two credits.
    final index = artistSearchIndex([
      _artist('Sơn Tùng'),
      _artist('Bích Phương'),
    ]);
    final hits = index.match(searchTerms('bich'));
    expect([for (final c in hits) c.name], ['Bích Phương']);
  });

  test(
    'names starting with the first term come first, then by track count',
    () {
      final index = albumSearchIndex([
        _album('Greatest Love', tracks: 50),
        _album('Love Songs', tracks: 2),
        _album('Love Story', tracks: 9),
        _album('Love Story', tracks: 9, artist: 'A'),
      ]);
      final hits = index.match(searchTerms('lov'));
      expect(
        [for (final a in hits) '${a.title}/${a.trackCount}/${a.artist}'],
        [
          'Love Story/9/null',
          'Love Story/9/A',
          'Love Songs/2/null',
          'Greatest Love/50/null',
        ],
      );
    },
  );

  test('no terms match nothing', () {
    expect(albumSearchIndex([_album('A')]).match(const []), isEmpty);
  });
}
