import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/queue_history_queries.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/core/queue_history/queue_history_recorder.dart';

import '../player/fake_audio_backend.dart';

Track song(String name) => Track.fromPath('/music/$name.mp3');

final a = song('a'), b = song('b'), c = song('c'), d = song('d');

void main() {
  late LibraryDatabase db;
  late ProviderContainer app;

  setUp(() {
    db = LibraryDatabase(NativeDatabase.memory());
    app = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        libraryDatabaseProvider.overrideWithValue(db),
      ],
    );
    app.listen(playerServiceProvider, (_, _) {});
    app.listen(queueHistoryRecorderProvider, (_, _) {});
  });

  tearDown(() async {
    app.dispose();
    await db.close();
  });

  PlayerService player() => app.read(playerServiceProvider.notifier);

  /// Lets the replaced-queue events arrive and their writes finish.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await app.read(queueHistoryRecorderProvider)!.idle;
  }

  Future<List<List<String>>> saved() async => [
    for (final s in await db.queueSnapshots())
      await db.queueSnapshotPaths(s.id),
  ];

  test('opening a new queue saves the one it replaces', () async {
    await player().openTracks([a, b, c]);
    await player().openTracks([d, a]);
    await settle();

    expect(await saved(), [
      [a.uri, b.uri, c.uri],
    ]);
  });

  test('saves the replaced queue in its play order', () async {
    await player().openShuffled([a, b, c, d]);
    final order = [
      for (final t in app.read(playerServiceProvider).queue.tracks) t.uri,
    ];
    await player().openTracks([a, b]);
    await settle();

    expect(await saved(), [order]);
  });

  test('a queue replaced by the same songs is not saved', () async {
    await player().openTracks([a, b, c]);
    await player().openTracks([a, b, c], start: 2);
    await settle();

    expect(await saved(), isEmpty);
  });

  test('play next, add to queue and the first open save nothing', () async {
    await player().openTracks([a, b]);
    await player().playNext([c]);
    await player().addToQueue([d]);
    await settle();

    expect(await saved(), isEmpty);
  });

  test('clearing the queue saves it', () async {
    await player().openTracks([a, b, c]);
    await player().clearQueue();
    await settle();

    expect(await saved(), [
      [a.uri, b.uri, c.uri],
    ]);
  });

  test('two quick opens save both replaced queues in order', () async {
    await player().openTracks([a, b]);
    final first = player().openTracks([c, d]);
    final second = player().openTracks([a, c]);
    await Future.wait([first, second]);
    await settle();

    expect(await saved(), [
      [c.uri, d.uri],
      [a.uri, b.uri],
    ]);
  });

  test('a rebuilt player is followed again', () async {
    await player().openTracks([a, b]);
    app.invalidate(playerServiceProvider);
    app.read(playerServiceProvider);
    await settle();
    await Future<void>.delayed(Duration.zero);

    await player().openTracks([a, b, c]);
    await player().openTracks([d, c]);
    await settle();

    expect(await saved(), [
      [a.uri, b.uri, c.uri],
    ]);
  });

  test('tracks that are not local files are left out', () async {
    const remote = Track(uri: 'http://example.test/x.mp3', title: 'x');
    await player().openTracks([a, remote, b]);
    await player().openTracks([c, d]);
    await settle();

    expect(await saved(), [
      [a.uri, b.uri],
    ]);
  });

  test('queuePaths of an empty queue is empty', () {
    expect(queuePaths(app.read(playerServiceProvider).queue), isEmpty);
  });
}
