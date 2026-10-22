import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart'
    show LibraryDatabase, TracksCompanion;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_audio_backend.dart';

Track song(String name) => Track.fromPath('/m/$name.flac');

/// When the automatic ReplayGain level of the playing track is decided
/// again: when a track starts, never for what edits the queue or the mode
/// around it.
void main() {
  late FakeAudioBackend backend;
  late LibraryDatabase db;
  late ProviderContainer container;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  Future<void> settle() => pumpEventQueue();

  setUp(() async {
    backend = FakeAudioBackend();
    db = LibraryDatabase(NativeDatabase.memory());
    final root = (await db.addRoots(['/m'], now: 1)).single;
    await db.upsertTracks([
      for (final (name, artist, album) in [
        ('a1', 'Ann', 'One'),
        ('a2', 'Ann', 'One'),
        ('b1', 'Bob', 'Two'),
        ('s', 'Cid', null),
      ])
        TracksCompanion.insert(
          rootId: root,
          path: '/m/$name.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: name,
          artist: Value(artist),
          album: Value(album),
          albumArtist: Value(artist),
          addedAt: 1,
          updatedAt: 1,
        ),
    ]);
    container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        audioBackendProvider.overrideWithValue(backend),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(
            playback: PlaybackPrefs(replayGainMode: ReplayGainMode.auto),
          ),
        ),
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
    // a2 plays between a1 and s: album gain.
    await service().openTracks([song('a1'), song('a2'), song('s')], start: 1);
    await settle();
    expect(backend.audioCalls.last, 'setReplayGain(album, 0.00, clip=no)');
    backend.audioCalls.clear();
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  final keepsLevel = <String, Future<void> Function(PlayerService)>{
    'turning shuffle on': (s) => s.setShuffle(true),
    'toggling shuffle': (s) => s.toggleShuffle(),
    'moving a track': (s) => s.moveTrack(0, 2),
    'play next': (s) => s.playNext([song('b1')]),
    'repeat all': (s) => s.setRepeat(RepeatMode.all),
    'removing another track': (s) => s.removeTrack(2),
  };
  for (final entry in keepsLevel.entries) {
    test('${entry.key} keeps the level of the playing track', () async {
      await entry.value(service());
      await settle();

      expect(backend.audioCalls, isEmpty);
    });
  }

  test('a repeat one loop keeps the level of the playing track', () async {
    await service().setRepeat(RepeatMode.one);
    await settle();
    backend.emitLooped.add(song('a2'));
    await settle();

    expect(backend.audioCalls, isEmpty);
  });

  test('removing the playing track decides for the one that follows', () async {
    await service().removeTrack(1); // s plays now, no album
    await settle();

    expect(backend.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
  });

  test('jumping to a track decides for it', () async {
    await service().jump(2);
    await settle();

    expect(backend.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
  });
}
