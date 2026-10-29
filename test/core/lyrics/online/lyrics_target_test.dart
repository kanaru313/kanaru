import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';

import '../../player/fake_audio_backend.dart';
import 'lookup_test_harness.dart';

void main() {
  const duration = Duration(seconds: 200);

  group('title rule', () {
    test('the file name is no title: not sent, not searchable, not keyed', () {
      final target = LyricsTarget.fromTrack(
        const Track(
          uri: '/music/01 - Track.flac',
          title: '01 - Track',
          artist: 'Artist',
          duration: duration,
        ),
      );
      expect(target.query.title, isNull);
      expect(target.isAutoSearchable, isFalse);
    });

    test('the cache key does not depend on the file name', () {
      LyricsTarget named(String file) => LyricsTarget.fromTrack(
        Track(
          uri: '/music/$file.flac',
          title: file,
          artist: 'Artist',
          album: 'Alb',
          duration: duration,
        ),
      );
      expect(named('first').cacheKey, named('second').cacheKey);
    });

    test('a real title is kept and searchable', () {
      final target = LyricsTarget.fromTrack(
        const Track(
          uri: '/music/a.flac',
          title: 'Real',
          artist: 'Artist',
          duration: duration,
        ),
      );
      expect(target.query.title, 'Real');
      expect(target.isAutoSearchable, isTrue);
    });

    test('a file uri gets the decoded path as key and path', () {
      final target = LyricsTarget.fromTrack(
        const Track(uri: 'file:///music/a%20b.flac', title: 'a b'),
      );
      expect(
        (target.trackKey, target.path),
        ('/music/a b.flac', '/music/a b.flac'),
      );
      expect(target.query.title, isNull);
    });

    test('a non-file uri keeps itself as key and has no path', () {
      final target = LyricsTarget.fromTrack(
        const Track(uri: 'https://x.example/s', title: 'T'),
      );
      expect((target.trackKey, target.path), ('https://x.example/s', null));
    });

    test('blank artist and album are dropped', () {
      final target = LyricsTarget.fromTrack(
        const Track(uri: '/m/a.flac', title: 'T', artist: ' ', album: ''),
      );
      expect((target.query.artist, target.query.album), (null, null));
    });

    test('equal fields are equal targets', () {
      LyricsTarget make() => LyricsTarget.fromFields(
        uri: '/m/a.flac',
        title: 'T',
        artist: 'A',
        duration: duration,
      );
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    });
  });

  group('from the library', () {
    late LyricsHarness h;
    late ProviderContainer container;

    setUp(() async {
      h = await createHarness([]);
      final root = await h.db
          .into(h.db.libraryRoots)
          .insert(LibraryRootsCompanion.insert(path: '/music', addedAt: 1));
      await h.db
          .into(h.db.tracks)
          .insert(
            TracksCompanion.insert(
              rootId: root,
              path: '/music/song.flac',
              mtimeMs: 1,
              sizeBytes: 1,
              addedAt: 1,
              updatedAt: 1,
              title: 'Old Title',
              artist: const Value('Old Artist'),
              durationMs: const Value(150000),
            ),
          );
      container = ProviderContainer(
        overrides: [
          audioBackendProvider.overrideWithValue(FakeAudioBackend()),
          libraryDatabaseProvider.overrideWithValue(h.db),
        ],
      );
      addTearDown(container.dispose);
      container.listen(playerServiceProvider, (_, _) {});
      container.listen(lyricsTargetProvider, (_, _) {});
    });

    test('a retagged row beats the stale queue track', () async {
      await h.db.customStatement(
        "UPDATE tracks SET title = 'Song', artist = 'Artist', "
        "album = 'Alb', duration_ms = 200000",
      );
      await container.read(playerServiceProvider.notifier).openTracks([
        const Track(
          uri: '/music/song.flac',
          title: 'Old Title',
          artist: 'Old Artist',
        ),
      ]);

      final target = await container.read(lyricsTargetProvider.future);

      final item = TrackListItem(
        id: 1,
        path: '/music/song.flac',
        title: 'Song',
        artist: 'Artist',
        album: 'Alb',
        durationMs: 200000,
      );
      expect(target!.cacheKey, LyricsTarget.fromListItem(item).cacheKey);
      expect(target, LyricsTarget.fromListItem(item));
    });

    test('a track outside the library uses its own fields', () async {
      await container.read(playerServiceProvider.notifier).openTracks([
        const Track(
          uri: '/elsewhere/x.flac',
          title: 'Mine',
          artist: 'Me',
          duration: duration,
        ),
      ]);

      final target = await container.read(lyricsTargetProvider.future);

      expect(target!.query.title, 'Mine');
    });

    test('nothing playing gives null', () async {
      expect(await container.read(lyricsTargetProvider.future), isNull);
    });
  });
}
