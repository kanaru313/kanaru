import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';

import 'fake_lyrics_provider.dart';
import 'status_test_rig.dart';

const _song = '/m/a.flac';

void main() {
  late StatusRig rig;
  late FakeLyricsProvider second;

  Future<void> start({List<Override> overrides = const []}) async {
    second = FakeLyricsProvider(id: 'second');
    rig = await createStatusRig(others: [second], overrides: overrides);
  }

  String key() => LyricsTarget.fromTrack(fakeSong(_song)).cacheKey;

  Future<void> missed(String providerId, {Duration age = Duration.zero}) =>
      rig.h.db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: key(),
          providerId: providerId,
          status: OnlineLyricsStatus.notFound.value,
          fetchedAt: rig.h.now.subtract(age).millisecondsSinceEpoch,
        ),
      );

  LyricsNoneReason? reason() => (rig.status as LyricsNone).reason;

  test(
    'one source missed, the other has no row: only the other runs',
    () async {
      await start();
      await missed('fake');
      rig.watch();
      await rig.play([fakeSong(_song)]);
      await rig.until(() => second.lookupCalls > 0);
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      expect(rig.fake.lookupCalls + rig.fake.searchCalls, 0);
      expect(second.lookupCalls, 1);
      expect(reason(), LyricsNoneReason.notFound);
    },
  );

  test('a stale miss is asked again, a fresh one is not', () async {
    await start();
    await missed('fake', age: const Duration(days: 15));
    await missed('second');
    rig.watch();
    await rig.play([fakeSong(_song)]);
    await rig.until(() => rig.fake.lookupCalls > 0);
    await rig.settle();

    expect(second.lookupCalls + second.searchCalls, 0);
  });

  test('every enabled source missed: not found and nothing runs', () async {
    await start();
    await missed('fake');
    await missed('second');
    rig.watch();
    await rig.play([fakeSong(_song)]);
    await rig.until(() => rig.status is LyricsNone);
    await rig.settle();

    expect(reason(), LyricsNoneReason.notFound);
    expect(rig.requests, 0);
  });

  test('a failure of one source shows over the other one missing', () async {
    await start();
    rig.fake.lookupResult = const LyricsFetchException(LyricsFetchKind.server);
    await missed('second');
    rig.watch();
    await rig.play([fakeSong(_song)]);
    await rig.until(() => rig.status is LyricsNone);
    await rig.settle();

    expect(reason(), LyricsNoneReason.error);
    expect((rig.status as LyricsNone).failure, LyricsFetchKind.server);
  });

  test(
    'one source missed, another unasked, no automatic consent: no search',
    () async {
      // Without the automatic consent nothing may run for the source that has
      // no row, and nothing may read as searching.
      second = FakeLyricsProvider(id: 'second');
      rig = await createStatusRig(others: [second], autoConsent: false);
      await missed('fake');
      rig.watch();
      await rig.play([fakeSong(_song)]);
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      expect(reason(), LyricsNoneReason.noLyrics);
      expect(rig.statuses.whereType<LyricsSearching>(), isEmpty);
      expect(rig.requests, 0);
    },
  );

  group('a known source that is not enabled', () {
    Future<void> startWithGone() => start(
      overrides: [
        lyricsSourceNamesProvider.overrideWithValue({
          'fake': const LyricsSourceName(displayName: 'Fake'),
          'second': const LyricsSourceName(displayName: 'Second'),
          'gone': const LyricsSourceName(displayName: 'Gone', removed: true),
        }),
      ],
    );

    test('its miss does not block the enabled sources', () async {
      await startWithGone();
      await missed('gone');
      rig.watch();
      await rig.play([fakeSong(_song)]);
      await rig.until(() => rig.fake.lookupCalls > 0);
      await rig.until(() => second.lookupCalls > 0);
    });

    test('its lyrics still show and nothing runs', () async {
      await startWithGone();
      await rig.h.db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: key(),
          providerId: 'gone',
          status: OnlineLyricsStatus.found.value,
          remoteId: const Value('9'),
          syncedText: const Value('[00:01.00] hello'),
          fetchedAt: rig.h.now.millisecondsSinceEpoch,
        ),
      );
      rig.watch();
      await rig.play([fakeSong(_song)]);
      await rig.until(() => rig.status is LyricsFound);
      await rig.settle();

      expect((rig.status as LyricsFound).origin!.providerId, 'gone');
      expect(rig.requests, 0);
    });
  });
}
