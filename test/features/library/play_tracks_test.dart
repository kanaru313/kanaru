import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart'
    show AlbumKey, BrowseTrack;
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/library_route_keys.dart';
import 'package:kanaru/features/library/play_tracks.dart';

import '../../core/indexer/fake_tag_reader.dart';
import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _covers = '/cache/kanaru/covers/512';
final _red = fakeCoverKey('red');

/// The cover of each queued track, by title.
Map<String, String?> _queuedArt(LibraryHarness h) => {
  for (final t in h.container.read(playerServiceProvider).queue.original)
    t.title: t.artUri,
};

void main() {
  group('trackFromItem', () {
    test('carries the thumbnail path as the art', () {
      final track = trackFromItem(
        path: '/m/a.flac',
        title: 'a',
        artist: 'Amy',
        durationMs: 1500,
        artPath: '$_covers/$_red',
      );
      expect(track.uri, '/m/a.flac');
      expect(track.title, 'a');
      expect(track.artist, 'Amy');
      expect(track.duration, const Duration(milliseconds: 1500));
      expect(track.artUri, '$_covers/$_red');
    });

    test('has no art without a thumbnail', () {
      expect(trackFromItem(path: '/m/a.flac', title: 'a').artUri, isNull);
    });
  });

  test('trackFromBrowse passes the art through', () {
    const row = BrowseTrack(id: 1, path: '/m/a.flac', title: 'a');
    expect(trackFromBrowse(row, artPath: '/c/x.jpg').artUri, '/c/x.jpg');
    expect(trackFromBrowse(row).artUri, isNull);
  });

  group('playing from the library queues the thumbnails', () {
    final tracks = [
      TestTrack('one', artist: 'Amy', album: 'Alpha', track: 1, coverKey: _red),
      TestTrack('two', artist: 'Amy', album: 'Alpha', track: 2),
    ];
    final expected = {'one': '$_covers/$_red', 'two': null};

    testWidgets('from the songs list', (tester) async {
      final h = LibraryHarness(coverCacheDirectory: _covers);
      await openWithTracks(tester, h, tracks, location: '/songs');
      await tester.tap(find.text('two'));
      await tester.pumpAndSettle();
      expect(_queuedArt(h), expected);
    });

    testWidgets('from an album page', (tester) async {
      final h = LibraryHarness(coverCacheDirectory: _covers);
      await openWithTracks(
        tester,
        h,
        tracks,
        location: albumLocation(const AlbumKey('amy', 'alpha')),
      );
      await tester.tap(find.text('two'));
      await tester.pumpAndSettle();
      expect(_queuedArt(h), expected);
    });

    testWidgets('from an artist page', (tester) async {
      final h = LibraryHarness(coverCacheDirectory: _covers);
      await openWithTracks(tester, h, tracks, location: artistLocation('amy'));
      await tester.tap(find.text('two').last);
      await tester.pumpAndSettle();
      expect(_queuedArt(h), expected);
    });

    testWidgets('with covers off nothing has art', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, tracks, location: '/songs');
      await tester.tap(find.text('two'));
      await tester.pumpAndSettle();
      expect(_queuedArt(h), {'one': null, 'two': null});
    });
  });
}
