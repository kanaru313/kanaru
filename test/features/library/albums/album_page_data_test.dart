import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_browse_rows.dart';
import 'package:kanaru/features/library/albums/album_page_data.dart';

AlbumPageData _page(AlbumKey key, String? artist, List<String?> credits) =>
    AlbumPageData(
      key: key,
      album: AlbumSummary(
        key: key,
        title: 'Album',
        artist: artist,
        trackCount: credits.length,
        addedAt: 1,
      ),
      tracks: [
        for (var i = 0; i < credits.length; i++)
          BrowseTrack(
            id: i,
            path: '/m/$i.flac',
            title: 'T$i',
            artist: credits[i],
            album: 'Album',
          ),
      ],
    );

void main() {
  test('links the album artist key when a track credits them', () {
    expect(
      _page(const AlbumKey('ann', 'album'), 'Ann', ['Ann']).linkedArtistKey,
      'ann',
    );
  });

  test('falls back to the shown artist when the key has none', () {
    const key = AlbumKey('', 'album');
    expect(_page(key, 'Ann', ['Bob', 'Ann']).linkedArtistKey, 'ann');
  });

  test('no link when no track credits the artist, or none is set', () {
    const key = AlbumKey('', 'album');
    expect(_page(key, 'Various Artists', ['Bob']).linkedArtistKey, isNull);
    expect(_page(key, null, ['Bob']).linkedArtistKey, isNull);
  });

  test('several album artists link the first one', () {
    const key = AlbumKey('', 'album');
    expect(_page(key, 'Ann; Bob', ['Bob', 'Ann']).linkedArtistKey, 'ann');
    expect(_page(key, 'Ann; Bob', ['Bob']).linkedArtistKey, isNull);
  });
}
