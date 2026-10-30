import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_lookups.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_streams.dart';

import 'counting_http_client.dart';
import 'fake_lyrics_provider.dart';
import 'lookup_test_harness.dart';

void main() {
  late FakeLyricsProvider fake;
  late CountingHttpClient client;

  Future<LyricsHarness> harness({
    bool autoFetch = true,
    bool autoConsent = true,
    bool manualConsent = true,
    bool withDatabase = true,
  }) {
    fake = FakeLyricsProvider();
    client = CountingHttpClient();
    return createHarness(
      [LyricsProviderRegistration(fake)],
      client: client,
      autoFetch: autoFetch,
      autoConsent: autoConsent,
      manualConsent: manualConsent,
      withDatabase: withDatabase,
    );
  }

  Future<List<OnlineLyricsRow>> rows(LyricsHarness h) =>
      h.db.watchOnlineLyrics(fakeTarget.cacheKey).first;

  Map<String, LookupState> states(LyricsHarness h) =>
      h.container.read(onlineLyricsLookupsProvider);

  group('answers that are stored', () {
    test('an exact record that passes the gate is stored as found', () async {
      final h = await harness();
      fake.lookupResult = fakeCandidate(remoteId: '7');

      await h.lookups.start(fakeTarget, auto: true);

      final row = (await rows(h)).single;
      expect((row.status, row.remoteId), ('found', '7'));
      expect(row.syncedText, '[00:01.00] hello');
      expect(row.remoteDurationMs, 200000);
      expect(fake.searchCalls, 0);
      expect(states(h), isEmpty);
      expect(h.backoff.isBlocked, isFalse);
    });

    test(
      'not found by lookup falls back to the best gated search hit',
      () async {
        final h = await harness();
        fake.searchResult = [
          fakeCandidate(remoteId: 'wrong', title: 'Other Title'),
          fakeCandidate(
            remoteId: 'late',
            duration: const Duration(seconds: 230),
          ),
          fakeCandidate(remoteId: 'good'),
        ];

        await h.lookups.start(fakeTarget, auto: true);

        expect((await rows(h)).single.remoteId, 'good');
      },
    );

    test('no search hit passing the gate stores not_found', () async {
      final h = await harness();
      fake.searchResult = [fakeCandidate(title: 'Other Title')];

      await h.lookups.start(fakeTarget, auto: true);

      final row = (await rows(h)).single;
      expect(row.status, 'not_found');
      expect(row.remoteId, isNull);
      expect(h.backoff.isBlocked, isFalse);
    });

    test('an empty valid search stores not_found', () async {
      final h = await harness();

      await h.lookups.start(fakeTarget, auto: true);

      expect((await rows(h)).single.status, 'not_found');
    });

    test('an instrumental record is stored without text', () async {
      final h = await harness();
      fake.lookupResult = fakeCandidate(
        body: const LyricsBody(instrumental: true),
      );

      await h.lookups.start(fakeTarget, auto: true);

      final row = (await rows(h)).single;
      expect(
        (row.status, row.instrumental, row.syncedText),
        ('found', true, null),
      );
    });
  });

  group('failures', () {
    for (final kind in [
      LyricsFetchKind.invalidResponse,
      LyricsFetchKind.server,
      LyricsFetchKind.network,
    ]) {
      test('a $kind in lookup stores nothing and starts the backoff', () async {
        final h = await harness();
        fake.lookupResult = LyricsFetchException(kind);

        await h.lookups.start(fakeTarget, auto: true);

        expect(await rows(h), isEmpty);
        expect(fake.searchCalls, 0);
        final state = states(h)[fakeTarget.cacheKey];
        expect(state, isA<LookupFailed>());
        expect((state! as LookupFailed).kind, kind);
        expect(h.backoff.isBlocked, isTrue);
      });
    }

    test('a failing search after TrackNotFound stores no not_found', () async {
      final h = await harness();
      fake.searchResult = const LyricsFetchException(
        LyricsFetchKind.invalidResponse,
      );

      await h.lookups.start(fakeTarget, auto: true);

      expect(await rows(h), isEmpty);
      expect(h.backoff.isBlocked, isTrue);
    });

    test('a start after a failure runs again and clears the failure', () async {
      final h = await harness();
      fake.lookupResult = const LyricsFetchException(LyricsFetchKind.server);
      await h.lookups.start(fakeTarget, auto: true);
      fake.lookupResult = fakeCandidate();

      await h.lookups.start(fakeTarget, auto: false);

      expect(fake.lookupCalls, 2);
      expect(states(h), isEmpty);
      expect((await rows(h)).single.status, 'found');
    });
  });

  group('forgetting failures', () {
    test('drops the failed entries and keeps the pause alone', () async {
      final h = await harness();
      fake.lookupResult = const LyricsFetchException(LyricsFetchKind.server);
      await h.lookups.start(fakeTarget, auto: true);
      expect(states(h)[fakeTarget.cacheKey], isA<LookupFailed>());

      h.lookups.forgetFailures();

      expect(states(h), isEmpty);
    });

    test(
      'a lookup held open across it records no failure and no pause',
      () async {
        final h = await harness();
        fake.gate = Completer();
        fake.lookupResult = const LyricsFetchException(LyricsFetchKind.server);

        final done = h.lookups.start(fakeTarget, auto: true);
        await Future<void>.delayed(Duration.zero);
        expect(states(h)[fakeTarget.cacheKey], isA<LookupRunning>());
        h.lookups.forgetFailures();
        fake.gate!.complete();
        await done;

        expect(states(h), isEmpty);
        expect(h.backoff.isBlocked, isFalse);
        expect(await rows(h), isEmpty);
      },
    );

    test('a lookup started afterwards fails as usual', () async {
      final h = await harness();
      h.lookups.forgetFailures();
      fake.lookupResult = const LyricsFetchException(LyricsFetchKind.server);

      await h.lookups.start(fakeTarget, auto: true);

      expect(states(h)[fakeTarget.cacheKey], isA<LookupFailed>());
      expect(h.backoff.isBlocked, isTrue);
    });
  });

  group('backoff', () {
    test('Retry-After 120 blocks for at least 120 s', () async {
      final h = await harness();
      fake.lookupResult = const LyricsFetchException(
        LyricsFetchKind.rateLimited,
        retryAfter: Duration(seconds: 120),
      );

      await h.lookups.start(fakeTarget, auto: true);

      h.now = h.now.add(const Duration(seconds: 119));
      expect(h.backoff.isBlocked, isTrue);
      h.now = h.now.add(const Duration(seconds: 2));
      expect(h.backoff.isBlocked, isFalse);
    });

    test('a short wait still blocks for 60 s', () async {
      final h = await harness();
      h.backoff.failed(const Duration(seconds: 5));
      h.now = h.now.add(const Duration(seconds: 59));
      expect(h.backoff.isBlocked, isTrue);
      h.now = h.now.add(const Duration(seconds: 2));
      expect(h.backoff.isBlocked, isFalse);
    });

    test('a huge wait is clamped to 15 minutes', () async {
      final h = await harness();
      h.backoff.failed(const Duration(days: 2));
      h.now = h.now.add(const Duration(minutes: 15, seconds: 1));
      expect(h.backoff.isBlocked, isFalse);
    });

    test('jitter adds up to 30 percent of the wait', () async {
      final h = await harness();
      h.backoff.failed(const Duration(seconds: 100));
      expect(
        h.container.read(onlineLyricsBackoffProvider),
        h.now.add(const Duration(seconds: 100)),
      );
      h.backoff.clear();
      h.jitter = 1;
      h.backoff.failed(const Duration(seconds: 100));
      expect(
        h.container.read(onlineLyricsBackoffProvider),
        h.now.add(const Duration(seconds: 130)),
      );
    });

    test(
      'clear ends the pause and a later failure does not shorten it',
      () async {
        final h = await harness();
        h.backoff.failed(const Duration(minutes: 10));
        final until = h.container.read(onlineLyricsBackoffProvider);
        h.backoff.failed();
        expect(h.container.read(onlineLyricsBackoffProvider), until);
        h.backoff.clear();
        expect(h.backoff.isBlocked, isFalse);
      },
    );
  });

  group('consent and eligibility', () {
    test(
      'without the auto key nothing is sent and nothing is recorded',
      () async {
        final h = await harness(autoConsent: false);

        await h.lookups.start(fakeTarget, auto: true);

        expect(fake.lookupCalls + fake.searchCalls, 0);
        expect(client.opened, 0);
        expect(h.backoff.isBlocked, isFalse);
        expect(states(h), isEmpty);
        expect(await rows(h), isEmpty);
      },
    );

    test('auto off blocks an automatic start but not a manual one', () async {
      final h = await harness(autoFetch: false);

      await h.lookups.start(fakeTarget, auto: true);
      expect(fake.lookupCalls, 0);

      await h.lookups.start(fakeTarget, auto: false);
      expect(fake.lookupCalls, 1);
    });

    test('a manual start needs the manual key', () async {
      final h = await harness(manualConsent: false);

      await h.lookups.start(fakeTarget, auto: false);

      expect(fake.lookupCalls, 0);
      expect(h.backoff.isBlocked, isFalse);
    });

    test('the provider receives the http the factory handed out', () async {
      final h = await harness();
      await h.lookups.start(fakeTarget, auto: true);
      expect(fake.received, isNotEmpty);
    });

    test('a target without an artist is never looked up', () async {
      final h = await harness();
      final target = LyricsTarget.fromFields(
        uri: '/music/song.flac',
        title: 'Song',
        duration: const Duration(seconds: 200),
      );

      await h.lookups.start(target, auto: false);

      expect(fake.lookupCalls + fake.searchCalls, 0);
    });

    test('without a library nothing is sent', () async {
      final h = await harness(withDatabase: false);
      await h.lookups.start(fakeTarget, auto: true);
      expect(fake.lookupCalls, 0);
    });
  });

  group('sources that already missed', () {
    Future<void> miss(LyricsHarness h) => h.db.saveOnlineLyrics(
      OnlineLyricsCompanion.insert(
        cacheKey: fakeTarget.cacheKey,
        providerId: 'fake',
        status: OnlineLyricsStatus.notFound.value,
        fetchedAt: h.now.millisecondsSinceEpoch,
      ),
    );

    test('a manual lookup asks again, an automatic one does not', () async {
      final h = await harness();
      await miss(h);

      await h.lookups.start(fakeTarget, auto: false);
      expect(fake.lookupCalls, 1);

      await miss(h);
      await h.lookups.start(fakeTarget, auto: true);
      expect(fake.lookupCalls, 1);
    });

    test('a failed cache read is a failure with a pause', () async {
      final h = await harness();
      await h.db.customStatement('DROP TABLE online_lyrics');

      await h.lookups.start(fakeTarget, auto: true);

      expect(states(h)[fakeTarget.cacheKey], isA<LookupFailed>());
      expect(h.backoff.isBlocked, isTrue);
      expect(fake.lookupCalls, 0);
    });
  });

  group('in flight', () {
    test('two starts for one key make one request', () async {
      final h = await harness();
      fake.gate = Completer();
      fake.lookupResult = fakeCandidate();

      final first = h.lookups.start(fakeTarget, auto: true);
      final second = h.lookups.start(fakeTarget, auto: false);
      await Future<void>.delayed(Duration.zero);

      expect(states(h)[fakeTarget.cacheKey], isA<LookupRunning>());
      fake.gate!.complete();
      await Future.wait([first, second]);

      expect(fake.lookupCalls, 1);
      expect(await rows(h), hasLength(1));
      await h.lookups.start(fakeTarget, auto: true);
      expect(fake.lookupCalls, 2);
    });

    test('a lookup finishes and stores its row when nobody watches', () async {
      final h = await harness();
      fake.gate = Completer();
      fake.lookupResult = fakeCandidate(remoteId: 'late');

      final done = h.lookups.start(fakeTarget, auto: true);
      await Future<void>.delayed(Duration.zero);
      fake.gate!.complete();
      await done;

      expect((await rows(h)).single.remoteId, 'late');
    });

    test('disposing the container during a lookup does not throw', () async {
      final h = await harness();
      fake.gate = Completer();
      fake.lookupResult = fakeCandidate();

      final done = h.lookups.start(fakeTarget, auto: true);
      await Future<void>.delayed(Duration.zero);
      h.container.dispose();
      fake.gate!.complete();
      await done;
    });
  });

  group('rejected records', () {
    Future<void> reject(LyricsHarness h, String remoteId) =>
        h.db.rejectOnlineLyrics(
          cacheKey: fakeTarget.cacheKey,
          providerId: 'fake',
          remoteId: remoteId,
          trackKey: fakeTarget.trackKey,
          now: 1,
        );

    test('a rejected exact record falls through to the next match', () async {
      final h = await harness();
      await reject(h, 'x');
      fake.lookupResult = fakeCandidate(remoteId: 'x');
      fake.searchResult = [
        fakeCandidate(remoteId: 'x'),
        fakeCandidate(remoteId: 'y'),
      ];

      await h.lookups.start(fakeTarget, auto: false);

      expect(fake.searchCalls, 1);
      expect((await rows(h)).single.remoteId, 'y');
    });

    test('when only rejected records match, not_found is stored', () async {
      final h = await harness();
      await reject(h, 'x');
      fake.searchResult = [fakeCandidate(remoteId: 'x')];

      await h.lookups.start(fakeTarget, auto: false);

      expect((await rows(h)).single.status, 'not_found');
    });
  });
}
