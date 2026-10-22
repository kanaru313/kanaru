import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' hide Track;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/core/stats/listen_recorder_provider.dart';

import '../database/library_database_test.dart' show track;
import '../player/fake_audio_backend.dart';
import 'listen_recorder_test_harness.dart';

void main() {
  late LibraryDatabase db;
  late FakeAudioBackend backend;
  late FakeListenClock time;

  setUp(() async {
    db = LibraryDatabase(NativeDatabase.memory());
    final roots = await db.addRoots(['/music'], now: 1);
    await db.upsertTracks([
      for (final t in [trackA, trackB])
        track(
          roots.single,
          t.uri,
          title: t.title,
        ).copyWith(durationMs: Value(t.duration?.inMilliseconds)),
    ]);
    backend = FakeAudioBackend();
    time = FakeListenClock();
  });
  tearDown(() => db.close());

  ProviderContainer launch({LibraryDatabase? library, bool record = true}) {
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        libraryDatabaseProvider.overrideWithValue(library),
        listenClockProvider.overrideWithValue(time.clock),
        initialSettingsProvider.overrideWithValue(
          AppSettings(recordListenHistory: record),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(listenRecorderProvider, (_, _) {});
    return container;
  }

  /// Engine ticks of [length] seconds, one per second, clock moving along.
  void tick(num length, {num from = 0}) {
    for (var t = from + 1; t <= from + length; t++) {
      time.advance(seconds(1));
      backend.emitPosition.add(seconds(t));
    }
  }

  Future<List<Play>> plays(ProviderContainer container) async {
    await container.read(listenRecorderProvider)!.idle;
    return db.select(db.plays).get();
  }

  test('ticks past the threshold leave one play row', () async {
    final container = launch(library: db);
    await container.read(playerServiceProvider.notifier).openTracks([trackA]);
    backend.emitDuration.add(trackA.duration!);

    tick(89);
    expect(await plays(container), isEmpty);
    tick(1, from: 89);

    final row = (await plays(container)).single;
    expect(row.path, trackA.uri);
    expect(await db.select(db.playStats).get(), hasLength(1));
  });

  test('switching the setting off stops new rows', () async {
    final container = launch(library: db);
    final player = container.read(playerServiceProvider.notifier);
    await player.openTracks([trackA, trackB]);
    backend.emitDuration.add(trackA.duration!);
    tick(90);
    expect(await plays(container), hasLength(1));

    container.read(settingsProvider.notifier).setRecordListenHistory(false);
    await player.next();
    backend.emitDuration.add(trackB.duration!);
    tick(300);

    expect(await plays(container), hasLength(1));
  });

  test('without a library database there is no recorder', () {
    final container = launch(library: null);
    expect(container.read(listenRecorderProvider), isNull);
  });
}
