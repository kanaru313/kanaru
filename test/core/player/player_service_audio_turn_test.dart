import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart'
    show LibraryDatabase, TracksCompanion;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
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
  var begun = false;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  Future<void> settle() => pumpEventQueue();

  /// Opens [names] at [at] in automatic mode and waits for the level to be
  /// decided: [level] is what it must be, so a case can tell a kept level
  /// from a decided again one.
  Future<void> begin(
    List<String> names,
    int at,
    String level, {
    Random? random,
  }) async {
    begun = true;
    container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        audioBackendProvider.overrideWithValue(backend),
        if (random != null)
          playerServiceProvider.overrideWith(
            () => PlayerService(random: random),
          ),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(
            playback: PlaybackPrefs(replayGainMode: ReplayGainMode.auto),
          ),
        ),
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
    await service().openTracks([for (final n in names) song(n)], start: at);
    await settle();
    expect(backend.audioCalls.last, 'setReplayGain($level, 0.00, clip=no)');
    backend.audioCalls.clear();
  }

  setUp(() async {
    begun = false;
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
  });
  tearDown(() async {
    if (begun) container.dispose();
    await db.close();
  });

  /// Each case starts where deciding again after the edit would give the
  /// other answer: a kept level is the token's doing, not luck.
  final keepsLevel =
      <
        String,
        ({
          List<String> queue,
          int at,
          String level,
          Future<void> Function(PlayerService) edit,
        })
      >{
        'play next (album run loses its next track)': (
          queue: ['s', 'a2', 'a1'],
          at: 1,
          level: 'album',
          edit: (s) => s.playNext([song('b1')]),
        ),
        'removing the other track of the run': (
          queue: ['s', 'a2', 'a1'],
          at: 1,
          level: 'album',
          edit: (s) => s.removeTrack(2),
        ),
        'repeat all (the queue wraps to a neighbour)': (
          queue: ['a2', 's', 'a1'],
          at: 0,
          level: 'track',
          edit: (s) => s.setRepeat(RepeatMode.all),
        ),
        'moving a track': (
          queue: ['a1', 'a2', 's'],
          at: 1,
          level: 'album',
          edit: (s) => s.moveTrack(0, 2),
        ),
      };
  for (final entry in keepsLevel.entries) {
    test('${entry.key} keeps the level of the playing track', () async {
      final c = entry.value;
      await begin(c.queue, c.at, c.level);

      await c.edit(service());
      await settle();

      expect(backend.audioCalls, isEmpty);
    });
  }

  for (final (name, shuffle)
      in <(String, Future<void> Function(PlayerService))>[
        ('turning shuffle on', (s) => s.setShuffle(true)),
        ('toggling shuffle', (s) => s.toggleShuffle()),
      ]) {
    test('$name keeps the level of the playing track', () async {
      // A seed that puts s, not a1, after a2, so shuffling alone would end
      // the album run.
      final tracks = [song('s'), song('a2'), song('a1')];
      final seed = [for (var i = 0; i < 100; i++) i].firstWhere((i) {
        final shuffled = PlayQueue.open(tracks, 1).shuffle(Random(i));
        return shuffled.trackAt(shuffled.nextIndex!).uri != song('a1').uri;
      });
      await begin(['s', 'a2', 'a1'], 1, 'album', random: Random(seed));

      await shuffle(service());
      await settle();

      final queue = container.read(playerServiceProvider).queue;
      expect(queue.trackAt(queue.nextIndex!).uri, song('s').uri);
      expect(backend.audioCalls, isEmpty);
    });
  }

  test('a repeat one loop keeps the level of the playing track', () async {
    await begin(['a1', 'a2', 's'], 1, 'album');
    await service().setRepeat(RepeatMode.one);
    await settle();
    backend.emitLooped.add(song('a2'));
    await settle();

    expect(backend.audioCalls, isEmpty);
  });

  test('removing the playing track decides for the one that follows', () async {
    await begin(['a1', 'a2', 's'], 1, 'album');
    await service().removeTrack(1); // s plays now, no album
    await settle();

    expect(backend.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
  });

  test('jumping to a track decides for it', () async {
    await begin(['a1', 'a2', 's'], 1, 'album');
    await service().jump(2);
    await settle();

    expect(backend.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
  });
}
