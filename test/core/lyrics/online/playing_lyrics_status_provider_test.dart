import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_actions.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status_provider.dart';
import 'package:kanaru/core/settings/settings_provider.dart';

import 'fake_lyrics_provider.dart';
import 'status_test_rig.dart';

const _lrc = '[00:00.00]local';

void main() {
  late StatusRig rig;

  Future<void> start({
    bool autoFetch = true,
    bool autoConsent = true,
    bool withDatabase = true,
    Duration debounce = rigDebounce,
    List<Override> overrides = const [],
  }) async {
    rig = await createStatusRig(
      autoFetch: autoFetch,
      autoConsent: autoConsent,
      withDatabase: withDatabase,
      debounce: debounce,
      overrides: overrides,
    );
  }

  LyricsNone none(Object? s) => s as LyricsNone;

  group('requests that must not happen', () {
    test('auto fetch off: three songs without lyrics send nothing', () async {
      await start(autoFetch: false);
      rig.watch();
      await rig.play([
        fakeSong('/m/a.flac', title: 'A'),
        fakeSong('/m/b.flac', title: 'B'),
        fakeSong('/m/c.flac', title: 'C'),
      ]);
      for (var i = 0; i < 3; i++) {
        await rig.until(() => rig.status is LyricsNone);
        await rig.settle();
        expect(none(rig.status).reason, LyricsNoneReason.noLyrics);
        if (i < 2) await rig.player.next();
      }
      expect(rig.requests, 0);
    });

    test('auto fetch on without auto consent sends nothing', () async {
      await start(autoConsent: false);
      rig.watch();
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      expect(none(rig.status).reason, LyricsNoneReason.noLyrics);
      expect(rig.requests, 0);
    });

    test('local lyrics with auto fetch on send nothing', () async {
      await start();
      rig.sidecar.byPath['/m/a.flac'] = _lrc;
      rig.watch();
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(() => rig.status is LyricsFound);
      await rig.settle();

      final found = rig.status as LyricsFound;
      expect(found.origin, isNull);
      expect(found.uri, '/m/a.flac');
      expect(rig.requests, 0);
    });

    test(
      'without a library local lyrics still show, nothing is sent',
      () async {
        await start(withDatabase: false);
        rig.sidecar.byPath['/m/a.flac'] = _lrc;
        rig.watch();
        await rig.play([fakeSong('/m/a.flac'), fakeSong('/m/b.flac')]);
        await rig.until(() => rig.status is LyricsFound);
        await rig.player.next();
        await rig.until(() => rig.status is LyricsNone);
        await rig.settle();

        expect(none(rig.status).reason, LyricsNoneReason.noLyrics);
        expect(rig.requests, 0);
      },
    );

    test('a stream error falls back to local lyrics only', () async {
      await start(
        overrides: [
          lyricsTargetProvider.overrideWith(
            (ref) => Stream<LyricsTarget?>.error(StateError('broken')),
          ),
        ],
      );
      rig.sidecar.byPath['/m/a.flac'] = _lrc;
      rig.watch();
      await rig.play([fakeSong('/m/a.flac'), fakeSong('/m/b.flac')]);
      await rig.until(() => rig.status is LyricsFound);
      await rig.player.next();
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      expect(none(rig.status).reason, LyricsNoneReason.noLyrics);
      expect(rig.requests, 0);
    });

    test('nothing watching the status sends nothing', () async {
      await start();
      await rig.play([fakeSong('/m/a.flac'), fakeSong('/m/b.flac')]);
      await rig.player.next();
      await rig.settle();

      expect(rig.requests, 0);
    });

    test('a title equal to the file name is never sent', () async {
      await start();
      rig.watch();
      await rig.play([fakeSong('/m/stem.flac', title: null)]);
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      expect(none(rig.status).reason, LyricsNoneReason.noLyrics);
      expect(rig.requests, 0);
      expect(
        LyricsTarget.fromTrack(fakeSong('/m/stem.flac', title: null)).cacheKey,
        LyricsTarget.fromTrack(fakeSong('/m/other.flac', title: null)).cacheKey,
      );
    });
  });

  group('automatic lookup', () {
    test('ten quick skips send one lookup, for the last song', () async {
      await start();
      rig.watch();
      await rig.play([
        for (var i = 0; i <= 10; i++) fakeSong('/m/s$i.flac', title: 'S$i'),
      ]);
      for (var i = 0; i < 10; i++) {
        await rig.player.next();
      }
      await rig.until(() => rig.fake.lookupCalls > 0);
      await rig.settle();

      expect(rig.fake.lookupCalls, 1);
      expect(rig.fake.queries.single.title, 'S10');
    });

    test('leaving during the wait sends nothing', () async {
      await start(debounce: const Duration(milliseconds: 150));
      rig.watch();
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(() => rig.status is LyricsSearching);
      rig.unwatch();
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(rig.requests, 0);
    });

    test('searches, then shows the match; no gap in between', () async {
      await start();
      final gate = rig.fake.gate = Completer<void>();
      rig.fake.lookupResult = fakeCandidate(remoteId: '7');
      rig.watch();
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(() => rig.fake.lookupCalls == 1);

      expect(rig.status, isA<LyricsSearching>());
      expect((rig.status as LyricsSearching).providerId, 'fake');
      gate.complete();
      await rig.until(() => rig.status is LyricsFound);

      final found = rig.status as LyricsFound;
      expect(found.origin!.remoteId, '7');
      expect(found.origin!.pinned, isFalse);
      expect(found.origin!.durationDelta, Duration.zero);
      expect(found.lyrics.synced, isTrue);
      expect(rig.statuses.whereType<LyricsNone>(), isEmpty);
      final rows = await rig.h.db
          .watchOnlineLyrics(
            LyricsTarget.fromTrack(fakeSong('/m/a.flac')).cacheKey,
          )
          .first;
      expect(rows.single.status, 'found');
      await rig.settle();
      expect(rig.requests, 1);
    });

    test('a library row is searched with its fresh tags', () async {
      await start();
      final rootId = (await rig.h.db.addRoots(['/m'], now: 1)).single;
      await rig.h.db.upsertTracks([
        TracksCompanion.insert(
          rootId: rootId,
          path: '/m/a.flac',
          mtimeMs: 1,
          sizeBytes: 1,
          title: 'Song',
          artist: const Value('Artist'),
          album: const Value('Alb'),
          durationMs: const Value(200000),
          addedAt: 1,
          updatedAt: 1,
        ),
      ]);
      rig.watch();
      await rig.play([fakeSong('/m/a.flac', title: 'Stale tag')]);
      await rig.until(() => rig.fake.lookupCalls == 1);
      await rig.until(() => rig.status is LyricsNone);

      expect(rig.fake.queries.single.title, 'Song');
      final fresh = LyricsTarget.fromFields(
        uri: '/m/a.flac',
        title: 'Song',
        artist: 'Artist',
        album: 'Alb',
        duration: const Duration(seconds: 200),
      );
      expect(
        await rig.h.db.watchOnlineLyrics(fresh.cacheKey).first,
        hasLength(1),
      );
    });

    test('no match is remembered 14 days, then asked again', () async {
      await start();
      rig.watch();
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(() => rig.status is LyricsNone);
      expect(none(rig.status).reason, LyricsNoneReason.notFound);
      final asked = rig.requests;
      expect(asked, 2);

      await rig.rewatch();
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();
      expect(none(rig.status).reason, LyricsNoneReason.notFound);
      expect(rig.requests, asked);

      await rig.rewatch(
        whileClosed: () => rig.h.now = rig.h.now.add(const Duration(days: 15)),
      );
      await rig.until(() => rig.requests > asked);
      await rig.until(() => rig.status is LyricsNone);
      expect(rig.fake.lookupCalls, 2);
    });

    test('a record without lyrics is an instrumental song', () async {
      await start();
      rig.fake.lookupResult = fakeCandidate(
        remoteId: '9',
        body: const LyricsBody(instrumental: true),
      );
      rig.watch();
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(() => rig.status is LyricsNone);

      expect(none(rig.status).reason, LyricsNoneReason.instrumental);
      expect(none(rig.status).origin!.remoteId, '9');
    });
  });

  group('failures', () {
    test('an error shows, pauses lookups and Retry sends again', () async {
      await start();
      rig.fake.lookupResult = const LyricsFetchException(
        LyricsFetchKind.server,
      );
      rig.watch();
      await rig.play([
        fakeSong('/m/a.flac'),
        fakeSong('/m/b.flac', title: 'B'),
      ]);
      await rig.until(() => rig.status is LyricsNone);

      expect(none(rig.status).reason, LyricsNoneReason.error);
      expect(rig.h.backoff.isBlocked, isTrue);
      expect(
        await rig.h.db
            .watchOnlineLyrics(
              LyricsTarget.fromTrack(fakeSong('/m/a.flac')).cacheKey,
            )
            .first,
        isEmpty,
      );

      await rig.player.next();
      await rig.until(() => rig.status?.uri == '/m/b.flac');
      await rig.settle();
      // The other song is waiting for the pause to end, and says so.
      expect(none(rig.status).reason, LyricsNoneReason.paused);
      expect(none(rig.status).resumeAt, rig.h.backoff.state['fake']);
      expect(rig.requests, 1);

      await rig.player.previous();
      rig.fake.lookupResult = fakeCandidate();
      await rig.container
          .read(onlineLyricsActionsProvider)
          .retry(LyricsTarget.fromTrack(fakeSong('/m/a.flac')));
      await rig.until(() => rig.status is LyricsFound);
      expect(rig.fake.lookupCalls, 2);
      expect(rig.h.backoff.isBlocked, isFalse);
    });

    test('a failed song is looked up again when the pause ends', () async {
      await start();
      rig.fake.lookupResult = const LyricsFetchException(
        LyricsFetchKind.server,
      );
      rig.watch();
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(() => rig.status is LyricsNone);
      final until = rig.h.backoff.state['fake']!;

      // Shown again just before the pause ends; nothing else changes.
      rig.h.now = until.subtract(const Duration(milliseconds: 300));
      await rig.rewatch();
      await rig.until(() => rig.status is LyricsNone);
      expect(none(rig.status).reason, LyricsNoneReason.error);
      rig.fake.lookupResult = fakeCandidate();
      rig.h.now = until.add(const Duration(seconds: 1));

      await rig.until(() => rig.status is LyricsFound);
      expect(rig.fake.lookupCalls, 2);
    });

    test('an old failure is not shown while a new lookup is due', () async {
      await start();
      rig.fake.lookupResult = const LyricsFetchException(
        LyricsFetchKind.server,
      );
      rig.watch();
      await rig.play([
        fakeSong('/m/a.flac'),
        fakeSong('/m/b.flac', title: 'B'),
        fakeSong('/m/a2.flac'),
      ]);
      await rig.until(() => rig.status is LyricsNone);
      rig.h.now = rig.h.backoff.state['fake']!.add(const Duration(seconds: 1));
      rig.fake.lookupResult = fakeCandidate();

      await rig.player.next();
      await rig.until(() => rig.status?.uri == '/m/b.flac');
      await rig.player.next();
      await rig.until(() => rig.status is LyricsFound);

      final frames = rig.statuses.where((s) => s?.uri == '/m/a2.flac');
      expect(frames.whereType<LyricsNone>(), isEmpty);
      expect(frames.whereType<LyricsSearching>(), isNotEmpty);
    });

    test('a rate limit pauses for the time asked', () async {
      await start();
      rig.fake.lookupResult = const LyricsFetchException(
        LyricsFetchKind.rateLimited,
        retryAfter: Duration(seconds: 120),
      );
      rig.watch();
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(() => rig.status is LyricsNone);

      expect((rig.status! as LyricsNone).failure, LyricsFetchKind.rateLimited);
      expect(
        rig.h.backoff.state['fake']!.difference(rig.h.now),
        greaterThanOrEqualTo(const Duration(seconds: 120)),
      );
    });
  });

  group('races and identity', () {
    test('a late answer for the previous song changes nothing', () async {
      await start();
      final gate = rig.fake.gate = Completer<void>();
      rig.fake.lookupResult = fakeCandidate();
      rig.sidecar.byPath['/m/b.flac'] = _lrc;
      rig.watch();
      await rig.play([
        fakeSong('/m/a.flac'),
        fakeSong('/m/b.flac', title: 'B'),
      ]);
      await rig.until(() => rig.fake.lookupCalls == 1);
      await rig.player.next();
      await rig.until(() => rig.status?.uri == '/m/b.flac');
      await rig.until(() => rig.status is LyricsFound);
      final before = rig.status;

      gate.complete();
      await rig.settle();

      expect(rig.status, before);
      final rows = await rig.h.db
          .watchOnlineLyrics(
            LyricsTarget.fromTrack(fakeSong('/m/a.flac')).cacheKey,
          )
          .first;
      expect(rows.single.status, 'found');
      expect(rig.fake.lookupCalls, 1);
    });

    test('a status rebuilt while a lookup runs sends one request', () async {
      await start();
      final gate = rig.fake.gate = Completer<void>();
      rig.watch();
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(() => rig.fake.lookupCalls == 1);
      await rig.rewatch();
      await rig.settle();
      gate.complete();
      await rig.until(() => rig.status is LyricsNone);
      await rig.settle();

      expect(rig.fake.lookupCalls, 1);
    });

    test('the same lyrics instance survives unrelated changes', () async {
      await start();
      rig.fake.lookupResult = fakeCandidate();
      rig.watch();
      await rig.play([fakeSong('/m/a.flac')]);
      await rig.until(() => rig.status is LyricsFound);
      final lyrics = (rig.status as LyricsFound).lyrics;

      await rig.h.db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: 'other',
          providerId: 'fake',
          status: 'not_found',
          fetchedAt: 1,
        ),
      );
      rig.h.backoff.failed('fake');
      final prefs = rig.container.read(settingsProvider).onlineLyrics;
      rig.container
          .read(settingsProvider.notifier)
          .setOnlineLyrics(prefs.copyWith(autoFetch: false));
      await rig.settle();

      expect(identical((rig.status as LyricsFound).lyrics, lyrics), isTrue);
    });
  });
}
