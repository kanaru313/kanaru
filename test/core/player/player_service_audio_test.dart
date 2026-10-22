import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor, Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart'
    show LibraryDatabase, TracksCompanion;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/player/audio_output_device.dart';
import 'package:kanaru/core/player/audio_output_devices_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_audio_backend.dart';

/// Counts the selects that reach the database.
class _CountingInterceptor extends QueryInterceptor {
  int selects = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects++;
    return super.runSelect(executor, statement, args);
  }
}

Track song(String name) => Track.fromPath('/m/$name.flac');

void main() {
  late FakeAudioBackend backend;
  late LibraryDatabase db;
  late _CountingInterceptor counter;
  late ProviderContainer container;

  PlayerService service() => container.read(playerServiceProvider.notifier);
  void setPlayback(PlaybackPrefs prefs) =>
      container.read(settingsProvider.notifier).setPlayback(prefs);

  Future<void> settle() => pumpEventQueue();

  ProviderContainer containerWith(List<Override> overrides) {
    final c = ProviderContainer(
      overrides: [libraryDatabaseProvider.overrideWithValue(db), ...overrides],
    );
    // Keeps the notifier alive and subscribed for the whole test.
    c.listen(playerServiceProvider, (_, _) {});
    return c;
  }

  setUp(() async {
    backend = FakeAudioBackend();
    counter = _CountingInterceptor();
    db = LibraryDatabase(NativeDatabase.memory().interceptWith(counter));
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
    container = containerWith([
      audioBackendProvider.overrideWithValue(backend),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('default settings make no audio call', () async {
    await service().openTracks([song('a1'), song('a2')]);
    await settle();

    expect(backend.audioCalls, isEmpty);
  });

  test('a ReplayGain setting is sent once', () async {
    await service().openTracks([song('a1'), song('a2')]);
    setPlayback(const PlaybackPrefs(replayGainMode: ReplayGainMode.track));
    await settle();

    expect(backend.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
  });

  test('auto follows the album of the playing track', () async {
    setPlayback(const PlaybackPrefs(replayGainMode: ReplayGainMode.auto));
    backend.audioCalls.clear();

    await service().openTracks([song('a1'), song('a2'), song('s')]);
    await settle();
    expect(backend.audioCalls, ['setReplayGain(album, 0.00, clip=no)']);
    backend.audioCalls.clear();

    backend.advance(); // a2: still the album, nothing to send
    await settle();
    expect(backend.audioCalls, isEmpty);

    backend.advance(); // s: no album
    await settle();
    expect(backend.audioCalls, ['setReplayGain(track, 0.00, clip=no)']);
  });

  test('the decision for a track reaches the engine before its open', () async {
    setPlayback(const PlaybackPrefs(replayGainMode: ReplayGainMode.auto));
    await service().openTracks([song('a1'), song('a2')]);
    await settle();
    // Plays a2 from the queue: the keys are cached, so no wait.
    final before = backend.audioCalls.length;
    await service().jump(1);
    await settle();

    expect(backend.calls.last, startsWith('open(a2'));
    expect(backend.audioCalls.length, before);
  });

  test('progress updates do not read the database', () async {
    setPlayback(const PlaybackPrefs(replayGainMode: ReplayGainMode.auto));
    await service().openTracks([song('a1'), song('a2')]);
    await settle();
    final selects = counter.selects;
    final calls = backend.audioCalls.length;

    for (var i = 1; i <= 20; i++) {
      backend.emitPosition.add(Duration(seconds: i));
    }
    await settle();

    expect(counter.selects, selects);
    expect(backend.audioCalls, hasLength(calls));
  });

  test(
    'the device that failed to open is shown, and cleared on a new pick',
    () async {
      const x = 'pipewire/x';
      container.listen(audioOutputFailedDeviceProvider, (_, _) {});
      backend.emitAudioDevices([
        const AudioOutputDevice(name: 'auto', description: ''),
        const AudioOutputDevice(name: x, description: 'X'),
      ]);
      setPlayback(const PlaybackPrefs().withAudioDevice(name: x));
      await settle();
      expect(backend.audioCalls, ['setAudioDevice($x)']);

      backend.emitAudioDeviceFailed(x);
      await settle();
      expect(container.read(audioOutputFailedDeviceProvider), x);

      setPlayback(const PlaybackPrefs());
      await settle();
      expect(container.read(audioOutputFailedDeviceProvider), isNull);
    },
  );

  test('a rebuilt service talks to the new engine only', () async {
    container.dispose();
    final engines = [FakeAudioBackend(), FakeAudioBackend()];
    var built = 0;
    container = containerWith([
      audioBackendProvider.overrideWith((ref) => engines[built++]),
    ]);
    await settle();

    container.invalidate(audioBackendProvider);
    await settle();
    setPlayback(const PlaybackPrefs(replayGainMode: ReplayGainMode.album));
    await settle();

    expect(engines[0].audioCalls, isEmpty);
    expect(engines[1].audioCalls, ['setReplayGain(album, 0.00, clip=no)']);
  });
}
