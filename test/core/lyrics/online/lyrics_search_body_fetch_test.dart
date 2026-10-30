import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/candidate_content_hash.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_search_controller.dart';

import 'bodyless_lyrics_provider.dart';
import 'counting_http_client.dart';
import 'fake_lyrics_provider.dart';
import 'lookup_test_harness.dart';

const _words = LyricsBody(syncedLrc: '[00:01.00] fetched words');

void main() {
  late BodylessLyricsProvider fake;
  late CountingHttpClient client;
  late LyricsHarness h;

  setUp(() async {
    fake = BodylessLyricsProvider();
    client = CountingHttpClient();
    h = await createHarness([LyricsProviderRegistration(fake)], client: client);
    // Keeps the autoDispose provider alive for the test.
    h.container.listen(lyricsSearchControllerProvider(fakeTarget), (_, _) {});
  });

  LyricsSearchController controller() =>
      h.container.read(lyricsSearchControllerProvider(fakeTarget).notifier);
  LyricsSearchState state() =>
      h.container.read(lyricsSearchControllerProvider(fakeTarget));

  LyricsCandidate bodyless(String id, {Duration? duration}) => fakeCandidate(
    remoteId: id,
    body: null,
    duration: duration ?? const Duration(seconds: 200),
  );

  group('auto-select', () {
    test('picks the first good match and fetches its lyrics', () async {
      fake.searchResult = [bodyless('a')];
      fake.bodies['a'] = _words;

      await controller().search('artist song');

      expect(fake.fetched, ['a']);
      final selection = state().selection!;
      expect(selection.candidate.remoteId, 'a');
      expect(selection.hasBody, isTrue);
      expect(selection.candidate.body!.syncedLrc, contains('fetched words'));
      expect(state().bodyFetches, isEmpty);
    });

    test('shows loading until the fetch is done', () async {
      final gate = fake.fetchGate = Completer<void>();
      fake.searchResult = [bodyless('a')];
      fake.bodies['a'] = _words;

      final searching = controller().search('artist song');
      await pumpEventQueue();

      expect(state().selection!.hasBody, isFalse);
      expect(state().selectionFetch!.phase, BodyFetchPhase.loading);

      gate.complete();
      await searching;

      expect(state().selection!.hasBody, isTrue);
      expect(state().selectionFetch, isNull);
    });

    test('a result with a body is preferred and nothing is fetched', () async {
      fake.searchResult = [bodyless('a'), fakeCandidate(remoteId: 'b')];

      await controller().search('artist song');

      expect(state().selection!.candidate.remoteId, 'b');
      expect(fake.fetched, isEmpty);
    });

    test('a match that is not good is not fetched by itself', () async {
      fake.searchResult = [
        fakeCandidate(remoteId: 'far', body: null, artist: 'Someone Else'),
      ];

      await controller().search('artist song');

      expect(state().selection, isNull);
      expect(fake.fetched, isEmpty);
      expect(state().results.single.selectable, isTrue);
    });
  });

  group('select', () {
    setUp(() {
      fake.searchResult = [
        fakeCandidate(remoteId: 'first'),
        fakeCandidate(
          remoteId: 'far',
          body: null,
          duration: const Duration(seconds: 230),
        ),
      ];
    });

    test('fetches the lyrics of a result that came without', () async {
      fake.bodies['far'] = _words;
      await controller().search('artist song');
      expect(fake.fetched, isEmpty);

      await controller().select(1);

      expect(fake.fetched, ['far']);
      expect(state().selection!.candidate.remoteId, 'far');
      expect(state().selection!.hasBody, isTrue);
      // The list keeps its order.
      expect(state().results.map((r) => r.candidate.remoteId), [
        'first',
        'far',
      ]);
    });

    test('a failure is kept, and selecting again tries again', () async {
      fake.bodies['far'] = const LyricsFetchException(LyricsFetchKind.network);
      await controller().search('artist song');

      await controller().select(1);

      expect(state().selection!.hasBody, isFalse);
      expect(state().selectionFetch!.phase, BodyFetchPhase.failed);
      expect(state().selectionFetch!.kind, LyricsFetchKind.network);

      fake.bodies['far'] = _words;
      await controller().select(1);

      expect(fake.fetched, ['far', 'far']);
      expect(state().selection!.hasBody, isTrue);
      expect(state().selectionFetch, isNull);
    });

    test('an unexpected error is a failure without a kind', () async {
      fake.bodies['far'] = StateError('boom');
      await controller().search('artist song');

      await controller().select(1);

      expect(state().selectionFetch!.phase, BodyFetchPhase.failed);
      expect(state().selectionFetch!.kind, isNull);
    });

    test('a second select while it loads does not fetch twice', () async {
      final gate = fake.fetchGate = Completer<void>();
      fake.bodies['far'] = _words;
      await controller().search('artist song');

      final first = controller().select(1);
      await pumpEventQueue();
      final second = controller().select(1);
      gate.complete();
      await Future.wait([first, second]);

      expect(fake.fetched, ['far']);
    });

    test('lyrics that do not exist make the result unselectable', () async {
      await controller().search('artist song');

      await controller().select(1);

      final far = state().results[1];
      expect(far.bodyMissing, isTrue);
      expect(far.selectable, isFalse);
      expect(state().selectionFetch, isNull);

      await controller().select(1);
      expect(fake.fetched, ['far'], reason: 'not asked again');
    });

    test('a fetched text equal to a rejected one is flagged', () async {
      const words = LyricsBody(plain: 'same words');
      await h.db.rejectOnlineLyrics(
        cacheKey: fakeTarget.cacheKey,
        providerId: 'fake',
        remoteId: 'old',
        contentHash: candidateContentHash(
          fakeCandidate(remoteId: 'old', body: words),
        ),
        trackKey: fakeTarget.trackKey,
        now: 1,
      );
      fake.bodies['far'] = words;
      await controller().search('artist song');

      await controller().select(1);

      expect(state().selection!.rejected, isTrue);
    });

    test('a fetched body is cleaned like a search answer', () async {
      fake.bodies['far'] = const LyricsBody(plain: 'a\r\nb\u0007');
      await controller().search('artist song');

      await controller().select(1);

      expect(state().selection!.candidate.body!.plain, 'a\nb');
    });
  });

  group('host checks', () {
    test('a list of nothing valid is an unreadable answer', () async {
      fake.searchResult = [fakeCandidate(remoteId: '')];

      await controller().search('artist song');

      expect(state().results, isEmpty);
      expect(state().byProvider['fake']!.kind, LyricsFetchKind.invalidResponse);
    });

    test('duplicates and extra results are dropped', () async {
      fake.searchResult = [
        for (var i = 0; i < 25; i++) fakeCandidate(remoteId: '${i % 22}'),
      ];

      await controller().search('artist song');

      final ids = state().results.map((r) => r.candidate.remoteId).toList();
      expect(ids, [for (var i = 0; i < 20; i++) '$i']);
    });
  });

  group('an automatic pick', () {
    test('gives way when its fetched text is a rejected one', () async {
      const rejectedWords = LyricsBody(plain: 'same words');
      await h.db.rejectOnlineLyrics(
        cacheKey: fakeTarget.cacheKey,
        providerId: 'fake',
        remoteId: 'old',
        contentHash: candidateContentHash(
          fakeCandidate(remoteId: 'old', body: rejectedWords),
        ),
        trackKey: fakeTarget.trackKey,
        now: 1,
      );
      fake.searchResult = [
        bodyless('a'),
        bodyless('b', duration: const Duration(seconds: 201)),
      ];
      fake.bodies['a'] = rejectedWords;
      fake.bodies['b'] = _words;

      await controller().search('artist song');

      expect(fake.fetched, ['a', 'b']);
      expect(state().selection!.candidate.remoteId, 'b');
      expect(state().selection!.hasBody, isTrue);
      expect(state().results.first.rejected, isTrue);
    });
  });

  group('a newer search', () {
    test('abandons the older one, which shows nothing', () async {
      fake
        ..holdSearches = true
        ..sendAfterGate = true;
      fake.searchResult = [fakeCandidate(remoteId: 'old')];

      final first = controller().search('first');
      await pumpEventQueue();
      expect(fake.searchGates, hasLength(1));
      fake.sendAfterGate = false;
      final second = controller().search('second');
      await pumpEventQueue();
      expect(fake.searchGates, hasLength(2));
      fake.searchResult = [fakeCandidate(remoteId: 'new')];

      fake.searchGates[0].complete();
      await first;

      expect(fake.abandonedSends, 1);
      expect(client.opened, 0, reason: 'the old search sent nothing');
      expect(state().query, 'second');
      expect(state().results, isEmpty);
      expect(state().byProvider['fake']!.phase, ProviderSearchPhase.searching);

      fake.searchGates[1].complete();
      await second;

      expect(state().results.map((r) => r.candidate.remoteId), ['new']);
      expect(state().byProvider['fake']!.phase, ProviderSearchPhase.done);
    });

    test('drops a fetch that finishes after it', () async {
      final gate = fake.fetchGate = Completer<void>();
      fake.searchResult = [bodyless('a')];
      fake.bodies['a'] = _words;
      final first = controller().search('first');
      await pumpEventQueue();
      expect(state().selectionFetch!.phase, BodyFetchPhase.loading);

      fake.fetchGate = null;
      fake.searchResult = [bodyless('b')];
      fake.bodies['b'] = const LyricsBody(plain: 'b words');
      await controller().search('second');
      gate.complete();
      await first;

      expect(state().results.map((r) => r.candidate.remoteId), ['b']);
      expect(state().selection!.candidate.body!.plain, 'b words');
      expect(state().bodyFetches, isEmpty);
    });
  });
}
