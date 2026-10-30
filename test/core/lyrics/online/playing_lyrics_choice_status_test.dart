import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_choice.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_source_provider.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';

import 'status_test_rig.dart';

const _lrc = '[00:00.00]local';

void main() {
  late StatusRig rig;
  final song = fakeSong('/m/a.flac');
  final target = LyricsTarget.fromTrack(song);

  Future<void> pin(String? mode, {bool pick = true, bool usable = true}) =>
      rig.h.db.pinLyrics(
        LyricsPinsCompanion.insert(
          trackKey: target.trackKey,
          pinnedAt: 1,
          mode: Value(mode),
          providerId: pick ? const Value('fake') : const Value.absent(),
          remoteId: pick ? const Value('pick') : const Value.absent(),
          syncedText: pick && usable
              ? const Value('[00:03.00] picked')
              : const Value.absent(),
        ),
      );

  Future<void> cache() => rig.h.db.saveOnlineLyrics(
    OnlineLyricsCompanion.insert(
      cacheKey: target.cacheKey,
      providerId: 'fake',
      status: 'found',
      remoteId: const Value('cached'),
      syncedText: const Value('[00:04.00] cached'),
      fetchedAt: 1,
    ),
  );

  Future<void> open({required bool local}) async {
    if (local) rig.sidecar.byPath['/m/a.flac'] = _lrc;
    rig.watch();
    await rig.play([song]);
    await rig.until(() => rig.status is! LyricsReading);
    await rig.settle();
  }

  String describe(PlayingLyricsStatus? s) => switch (s) {
    LyricsFound(:final lyrics, :final origin) =>
      '${lyrics.lines.single.text}${origin == null
          ? ''
          : origin.pinned
          ? ' (pick)'
          : ' (cache)'}',
    LyricsNone(:final reason) => reason.name,
    _ => '$s',
  };

  LyricsSourceResolution source() =>
      rig.container.read(playingLyricsSourceProvider)!;

  // (mode, pick, local, cache) -> (shown, effective). For `online` the pick
  // is usable or not; for `local` and `off` it is stored or absent.
  final cases = <(String?, bool, bool, bool), (String, LyricsChoice)>{
    // off: nothing else matters
    ('off', true, true, true): ('off', LyricsChoice.off),
    ('off', false, false, true): ('off', LyricsChoice.off),
    // online with a usable pick wins over local and cache
    ('online', true, true, true): ('picked (pick)', LyricsChoice.online),
    ('online', true, false, false): ('picked (pick)', LyricsChoice.online),
    // online with an unusable pick goes automatic
    ('online', false, true, true): ('local', LyricsChoice.auto),
    ('online', false, false, true): ('cached (cache)', LyricsChoice.auto),
    ('online', false, false, false): ('noLyrics', LyricsChoice.auto),
    // local
    ('local', true, true, true): ('local', LyricsChoice.local),
    ('local', true, false, true): ('cached (cache)', LyricsChoice.auto),
    ('local', true, false, false): ('noLyrics', LyricsChoice.auto),
    ('local', false, false, true): ('cached (cache)', LyricsChoice.auto),
    ('off', true, false, false): ('off', LyricsChoice.off),
    // auto (no row, or a row without a mode)
    (null, false, true, true): ('local', LyricsChoice.auto),
    (null, false, false, true): ('cached (cache)', LyricsChoice.auto),
    (null, false, false, false): ('noLyrics', LyricsChoice.auto),
  };

  group('what each choice shows', () {
    for (final entry in cases.entries) {
      final (mode, usablePick, hasLocal, hasCache) = entry.key;
      final (shown, effective) = entry.value;
      test(
        'choice ${mode ?? 'auto'}, usable pick $usablePick, local $hasLocal, '
        'cache $hasCache: $shown',
        () async {
          rig = await createStatusRig(autoFetch: false);
          if (mode != null) {
            await pin(
              mode,
              pick: mode == 'online' || usablePick,
              usable: usablePick,
            );
          }
          if (hasCache) await cache();
          final writes = <Object?>[];
          final sub = rig.h.db.tableUpdates().listen(writes.add);
          addTearDown(sub.cancel);
          await open(local: hasLocal);

          expect(writes, isEmpty, reason: 'resolving writes nothing');
          expect(describe(rig.status), shown);
          expect(source().effective, effective);
          expect(source().chosen, parseLyricsChoice(mode));
          expect(source().hasLocal, hasLocal);
          expect(rig.requests, 0);
        },
      );
    }

    test('a choice without a pick does not look anything up', () async {
      rig = await createStatusRig();
      await pin('off', pick: false);
      await open(local: false);

      expect(rig.requests, 0);
      expect((rig.status as LyricsNone).reason, LyricsNoneReason.off);
    });
  });

  group('lookup states', () {
    final failing = const LyricsFetchException(LyricsFetchKind.server);

    Future<void> failFirstSong() async {
      rig = await createStatusRig();
      rig.fake.lookupResult = failing;
      rig.watch();
      await rig.play([song, fakeSong('/m/b.flac', title: 'B')]);
      await rig.until(() => rig.status is LyricsNone);
    }

    test('another song waits for the pause and reports when it ends', () async {
      await failFirstSong();
      await rig.player.next();
      await rig.until(() => rig.status?.uri == '/m/b.flac');
      await rig.settle();

      final status = rig.status as LyricsNone;
      expect(status.reason, LyricsNoneReason.paused);
      expect(status.resumeAt, rig.h.backoff.state);
    });

    test('a longer pause updates the time it reports', () async {
      await failFirstSong();
      await rig.player.next();
      await rig.until(
        () => rig.status is LyricsNone && rig.status?.uri == '/m/b.flac',
      );
      await rig.settle();
      final first = (rig.status as LyricsNone).resumeAt!;

      rig.h.backoff.failed(const Duration(seconds: 120));
      await rig.until(() => (rig.status as LyricsNone).resumeAt != first);

      expect((rig.status as LyricsNone).resumeAt, rig.h.backoff.state);
      expect((rig.status as LyricsNone).resumeAt!.isAfter(first), isTrue);
    });

    test('a failure of the song itself beats the pause', () async {
      await failFirstSong();
      await rig.settle();

      expect((rig.status as LyricsNone).reason, LyricsNoneReason.error);
    });

    test('a lookup in flight beats the pause', () async {
      await failFirstSong();
      await rig.player.next();
      await rig.until(() => rig.status?.uri == '/m/b.flac');
      await rig.settle();
      rig.fake.gate = Completer<void>();
      rig.fake.lookupResult = null;

      final done = rig.h.lookups.start(
        LyricsTarget.fromTrack(fakeSong('/m/b.flac', title: 'B')),
        auto: false,
      );
      await rig.until(() => rig.status is LyricsSearching);
      rig.fake.gate!.complete();
      await done;
    });

    test('forgetting failures clears the error', () async {
      await failFirstSong();
      expect((rig.status as LyricsNone).reason, LyricsNoneReason.error);
      rig.h.lookups.forgetFailures();
      rig.h.backoff.clear();
      rig.fake.lookupResult = null;
      await rig.until(
        () =>
            rig.status is! LyricsNone ||
            (rig.status as LyricsNone).reason != LyricsNoneReason.error,
      );
    });
  });
}
