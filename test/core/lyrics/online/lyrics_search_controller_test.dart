import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_search_controller.dart';

import 'fake_lyrics_provider.dart';
import 'lookup_test_harness.dart';

/// Answers each search from the next completer, so a test decides the order
/// in which searches finish.
class _HeldProvider extends FakeLyricsProvider {
  final pending = <Completer<List<LyricsCandidate>>>[];

  @override
  Future<List<LyricsCandidate>> search(LyricsQuery query, LyricsHttp http) {
    searchCalls++;
    queries.add(query);
    final c = Completer<List<LyricsCandidate>>();
    pending.add(c);
    return c.future;
  }
}

void main() {
  late FakeLyricsProvider fake;
  late LyricsHarness h;

  Future<void> setUpWith(
    FakeLyricsProvider provider, {
    bool manualConsent = true,
  }) async {
    fake = provider;
    h = await createHarness([
      LyricsProviderRegistration(provider),
    ], manualConsent: manualConsent);
  }

  LyricsSearchController controller() =>
      h.container.read(lyricsSearchControllerProvider(fakeTarget).notifier);
  LyricsSearchState state() =>
      h.container.read(lyricsSearchControllerProvider(fakeTarget));

  // Keeps the autoDispose provider alive for the test.
  void keepAlive() =>
      h.container.listen(lyricsSearchControllerProvider(fakeTarget), (_, _) {});

  Future<void> searchWith(List<LyricsCandidate> found) async {
    fake.searchResult = found;
    await controller().search('artist song');
  }

  group('search', () {
    setUp(() async => setUpWith(FakeLyricsProvider()));

    test('starts from the primary artist and title', () {
      keepAlive();
      expect(state().query, 'Artist Song');
      expect(state().results, isEmpty);
      expect(state().byProvider, isEmpty);
    });

    test('ranks good matches first, then synced, then smaller delta', () async {
      keepAlive();
      await searchWith([
        fakeCandidate(
          remoteId: 'far-plain',
          duration: const Duration(seconds: 230),
          body: const LyricsBody(plain: 'words'),
        ),
        fakeCandidate(
          remoteId: 'good-plain',
          body: const LyricsBody(plain: 'words'),
        ),
        fakeCandidate(
          remoteId: 'far-synced',
          duration: const Duration(seconds: 230),
        ),
        fakeCandidate(
          remoteId: 'near-synced',
          duration: const Duration(seconds: 204),
          body: const LyricsBody(syncedLrc: '[00:01.00] a'),
        ),
        fakeCandidate(remoteId: 'good-synced'),
      ]);

      expect(state().results.map((r) => r.candidate.remoteId), [
        'good-synced',
        'good-plain',
        'near-synced',
        'far-synced',
        'far-plain',
      ]);
      expect(state().results.first.match.goodMatch, isTrue);
      expect(state().results[2].match.goodMatch, isFalse);
    });

    test('selects the first candidate that has lyrics', () async {
      keepAlive();
      await searchWith([
        fakeCandidate(remoteId: 'empty', body: null),
        fakeCandidate(remoteId: 'ok'),
      ]);

      final results = state().results;
      expect(results.first.candidate.remoteId, 'ok');
      expect(state().selection!.candidate.remoteId, 'ok');
      expect(results.last.selectable, isFalse);
      controller().select(1);
      expect(state().selected, 1);
      controller().select(null);
      expect(state().selection, isNull);
    });

    test('rejected records are left out', () async {
      keepAlive();
      await h.db.rejectOnlineLyrics(
        cacheKey: fakeTarget.cacheKey,
        providerId: 'fake',
        remoteId: 'bad',
        trackKey: fakeTarget.trackKey,
        now: 1,
      );
      await searchWith([
        fakeCandidate(remoteId: 'bad'),
        fakeCandidate(remoteId: 'ok'),
      ]);

      expect(state().results.map((r) => r.candidate.remoteId), ['ok']);
    });

    test('keeps at most 20 results', () async {
      keepAlive();
      await searchWith([
        for (var i = 0; i < 30; i++) fakeCandidate(remoteId: 'r$i'),
      ]);

      expect(state().results, hasLength(maxSearchResults));
    });

    test('tracks each provider and ends done', () async {
      keepAlive();
      final future = controller().search('x');
      expect(state().byProvider['fake']!.phase, ProviderSearchPhase.searching);
      expect(state().searching, isTrue);
      await future;
      expect(state().byProvider['fake']!.phase, ProviderSearchPhase.done);
      expect(state().searching, isFalse);
    });

    test('an error is shown and Retry searches again', () async {
      keepAlive();
      fake.searchResult = const LyricsFetchException(LyricsFetchKind.network);
      await controller().search('x');
      final failed = state().byProvider['fake']!;
      expect(failed.phase, ProviderSearchPhase.error);
      expect(failed.kind, LyricsFetchKind.network);

      fake.searchResult = [fakeCandidate()];
      await controller().retry();
      expect(state().byProvider['fake']!.phase, ProviderSearchPhase.done);
      expect(state().results, hasLength(1));
      expect(fake.searchCalls, 2);
      expect(state().query, 'x');
    });

    test('a blank text sends nothing', () async {
      keepAlive();
      await controller().search('   ');
      expect(fake.searchCalls, 0);
      expect(state().query, 'Artist Song');
    });
  });

  test('an older search never replaces a newer one', () async {
    final held = _HeldProvider();
    await setUpWith(held);
    keepAlive();

    final first = controller().search('one');
    await pumpEventQueue();
    final second = controller().search('two');
    await pumpEventQueue();
    expect(held.pending, hasLength(2));
    expect(held.queries.map((q) => q.text), ['one', 'two']);

    held.pending[1].complete([fakeCandidate(remoteId: 'new')]);
    await second;
    held.pending[0].complete([fakeCandidate(remoteId: 'old')]);
    await first;

    expect(state().query, 'two');
    expect(state().results.map((r) => r.candidate.remoteId), ['new']);
    expect(state().byProvider['fake']!.phase, ProviderSearchPhase.done);
  });

  test('finishing after the controller is gone does nothing', () async {
    final held = _HeldProvider();
    await setUpWith(held);
    final sub = h.container.listen(
      lyricsSearchControllerProvider(fakeTarget),
      (_, _) {},
    );
    final searching = controller().search('x');
    await pumpEventQueue();

    sub.close();
    await pumpEventQueue();
    expect(
      h.container.exists(lyricsSearchControllerProvider(fakeTarget)),
      isFalse,
    );
    held.pending.single.complete([fakeCandidate()]);

    await searching;
  });

  test(
    'without consent nothing is sent and the provider shows an error',
    () async {
      await setUpWith(FakeLyricsProvider(), manualConsent: false);
      keepAlive();

      await controller().search('x');

      expect(fake.searchCalls, 0);
      final failed = state().byProvider['fake']!;
      expect(failed.phase, ProviderSearchPhase.error);
      expect(failed.kind, LyricsFetchKind.notConsented);
    },
  );
}
