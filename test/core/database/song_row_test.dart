import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/song_row.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/shared/play_tracks.dart';

import '../indexer/fake_tag_reader.dart';

const _covers = '/cache/covers/512';
final _cover = fakeCoverKey('red');

void main() {
  // The same song as a list row and as an album or artist page row.
  final SongRow listRow = TrackListItem(
    id: 4,
    path: '/m/Rock/a.flac',
    title: 'A',
    artist: 'Ann; Bob',
    album: 'Blue',
    year: 1999,
    durationMs: 215000,
    coverKey: _cover,
  );
  final SongRow pageRow = BrowseTrack(
    id: 4,
    path: '/m/Rock/a.flac',
    title: 'A',
    artist: 'Ann; Bob',
    album: 'Blue',
    albumArtist: 'Ann',
    year: 1999,
    discNo: 1,
    trackNo: 3,
    durationMs: 215000,
    albumKey: const AlbumKey('ann', 'blue'),
    coverKey: _cover,
  );

  test('both rows give the same queue entry', () {
    final a = trackFromRow(listRow, _covers);
    final b = trackFromRow(pageRow, _covers);
    expect(a, b);
    for (final t in [a, b]) {
      expect(t.uri, '/m/Rock/a.flac');
      expect(t.title, 'A');
      expect(t.artist, 'Ann; Bob');
      expect(t.album, 'Blue');
      expect(t.year, 1999);
      expect(t.duration, const Duration(milliseconds: 215000));
      expect(t.artUri, '$_covers/$_cover');
    }
  });

  test('both rows give the same lyrics target', () {
    final a = LyricsTarget.fromSongRow(listRow);
    final b = LyricsTarget.fromSongRow(pageRow);
    expect(a, b);
    expect(a.cacheKey, b.cacheKey);
    expect(a.path, '/m/Rock/a.flac');
  });
}
