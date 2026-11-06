import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/core/sources/remote_source_ref.dart';
import 'package:kanaru/core/sources/source_plugin_runner.dart';
import 'package:kanaru/features/online_sources/online_search_controller.dart';

import 'online_test_support.dart';

void main() {
  late RecordsProvider records;

  ProviderContainer make(FakeSourceRunner runner) {
    records = testRecords(AsyncData([sourceRecord()]));
    final container = ProviderContainer(
      overrides: [
        sourcePluginRunnerProvider.overrideWithValue(runner),
        ...onlineOverrides(records),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  OnlineSearchController controllerOf(ProviderContainer c) =>
      c.read(onlineSearchControllerProvider.notifier);
  OnlineSearchState stateOf(ProviderContainer c) =>
      c.read(onlineSearchControllerProvider);

  test('results become remote tracks of the plugin, in order', () async {
    final runner = FakeSourceRunner((_, _, _) async => pageOf(2));
    final c = make(runner);
    await controllerOf(c).search(sourceId, '  cats ');

    final state = stateOf(c) as OnlineSearchResults;
    expect(runner.searches, ['$sourceId|cats']);
    expect(state.tracks.map((t) => t.title), ['Song 1', 'Song 2']);
    expect(state.tracks.first.artist, 'Artist 1');
    expect(state.tracks.first.duration, const Duration(minutes: 1, seconds: 5));
    expect(state.tracks.first.remote?.installId, sourceId);
    expect(state.tracks.first.remote?.itemId, 'id1');
    expect(state.tracks.first.uri, remoteTrackUri(state.tracks.first.remote!));
    expect(state.tracks.first.artUri, isNull);
  });

  test('a blank query sends nothing', () async {
    final runner = FakeSourceRunner((_, _, _) async => pageOf(1));
    final c = make(runner);
    await controllerOf(c).search(sourceId, '   ');

    expect(runner.searches, isEmpty);
    expect(stateOf(c), isA<OnlineSearchIdle>());
  });

  test('an empty page is the empty state', () async {
    final c = make(FakeSourceRunner((_, _, _) async => pageOf(0)));
    await controllerOf(c).search(sourceId, 'x');

    expect(stateOf(c), isA<OnlineSearchEmpty>());
  });

  test('a superseded search is abandoned and its result dropped', () async {
    final first = Completer<SourceSearchPage>();
    bool Function()? firstAbandoned;
    final runner = FakeSourceRunner((_, query, abandoned) {
      if (query == 'old') {
        firstAbandoned = abandoned;
        return first.future;
      }
      return Future.value(pageOf(1));
    });
    final c = make(runner);
    final old = controllerOf(c).search(sourceId, 'old');
    expect(firstAbandoned!(), isFalse);

    await controllerOf(c).search(sourceId, 'new');
    expect(firstAbandoned!(), isTrue);
    first.complete(pageOf(3));
    await old;

    final state = stateOf(c) as OnlineSearchResults;
    expect(state.query, 'new');
    expect(state.tracks, hasLength(1));
  });

  test('a failure keeps its kind and the plugin message', () async {
    final c = make(
      FakeSourceRunner(
        (_, _, _) async => throw const SourceFailure(
          kind: SourceFailureKind.rateLimited,
          message: 'slow down',
        ),
      ),
    );
    await controllerOf(c).search(sourceId, 'x');

    final state = stateOf(c) as OnlineSearchFailed;
    expect(state.kind, SourceFailureKind.rateLimited);
    expect(state.message, 'slow down');
  });

  test('a call that was dropped (skipped) reports nothing', () async {
    final c = make(
      FakeSourceRunner(
        (_, _, _) async =>
            throw const SourceFailure(kind: SourceFailureKind.skipped),
      ),
    );
    await controllerOf(c).search(sourceId, 'x');

    expect(stateOf(c), isA<OnlineSearchIdle>());
  });

  test('retry runs the failed search again', () async {
    var calls = 0;
    final runner = FakeSourceRunner((_, _, _) async {
      if (++calls == 1) {
        throw const SourceFailure(kind: SourceFailureKind.network);
      }
      return pageOf(1);
    });
    final c = make(runner);
    await controllerOf(c).search(sourceId, 'x');
    expect(stateOf(c), isA<OnlineSearchFailed>());

    await controllerOf(c).retry();
    expect(stateOf(c), isA<OnlineSearchResults>());
    expect(runner.searches, ['$sourceId|x', '$sourceId|x']);
  });

  test('without consent the search waits; accepting runs it', () async {
    var consented = false;
    late ProviderContainer c;
    final runner = FakeSourceRunner((_, _, _) async {
      final ids = c.read(settingsProvider).onlineSources.noticeAcknowledged;
      consented = ids.contains(sourceId);
      if (!consented) {
        throw const SourceFailure(kind: SourceFailureKind.notConsented);
      }
      return pageOf(1);
    });
    c = make(runner);
    await controllerOf(c).search(sourceId, 'x');
    final waiting = stateOf(c) as OnlineSearchConsent;
    expect(waiting.query, 'x');

    await controllerOf(c).acceptNotice();

    expect(c.read(settingsProvider).onlineSources.noticeAcknowledged, {
      sourceId,
    });
    expect(stateOf(c), isA<OnlineSearchResults>());
    expect(runner.searches, hasLength(2));
  });

  group('a plugin drop', () {
    const other = 'plugin-bbbbbbbbbbbb';

    void consentTo(ProviderContainer c, String id) =>
        c.read(settingsProvider.notifier).acknowledgeSourceNotice(id);

    test('removing the plugin clears its shown results', () async {
      final c = make(FakeSourceRunner((_, _, _) async => pageOf(2)));
      consentTo(c, sourceId);
      await controllerOf(c).search(sourceId, 'x');
      expect(stateOf(c), isA<OnlineSearchResults>());

      c.read(records.notifier).set(const AsyncData([]));
      await pumpEventQueue();

      expect(stateOf(c), isA<OnlineSearchIdle>());
    });

    test('withdrawing the notice clears its shown results', () async {
      final c = make(FakeSourceRunner((_, _, _) async => pageOf(2)));
      consentTo(c, sourceId);
      await controllerOf(c).search(sourceId, 'x');

      c.read(settingsProvider.notifier).withdrawSourceNotice(sourceId);

      expect(stateOf(c), isA<OnlineSearchIdle>());
    });

    test('the drop of another plugin leaves the results alone', () async {
      final c = make(FakeSourceRunner((_, _, _) async => pageOf(2)));
      consentTo(c, sourceId);
      consentTo(c, other);
      c
          .read(records.notifier)
          .set(AsyncData([sourceRecord(), sourceRecord(id: other)]));
      await controllerOf(c).search(sourceId, 'x');

      c.read(records.notifier).set(AsyncData([sourceRecord()]));
      await pumpEventQueue();
      c.read(settingsProvider.notifier).withdrawSourceNotice(other);

      expect(stateOf(c), isA<OnlineSearchResults>());
    });

    test(
      'a search in flight ends skipped when the plugin is removed',
      () async {
        final reply = Completer<SourceSearchPage>();
        final c = make(FakeSourceRunner((_, _, _) => reply.future));
        consentTo(c, sourceId);
        final running = controllerOf(c).search(sourceId, 'x');

        c.read(records.notifier).set(const AsyncData([]));
        await pumpEventQueue();
        reply.completeError(
          const SourceFailure(kind: SourceFailureKind.skipped),
        );
        await running;

        expect(stateOf(c), isA<OnlineSearchIdle>());
      },
    );

    test(
      'a search in flight ends with the notice when consent is withdrawn',
      () async {
        final reply = Completer<SourceSearchPage>();
        final c = make(FakeSourceRunner((_, _, _) => reply.future));
        consentTo(c, sourceId);
        final running = controllerOf(c).search(sourceId, 'x');

        c.read(settingsProvider.notifier).withdrawSourceNotice(sourceId);
        reply.completeError(
          const SourceFailure(kind: SourceFailureKind.notConsented),
        );
        await running;

        expect(stateOf(c), isA<OnlineSearchConsent>());
      },
    );
  });

  test('no runner (no database) is an internal failure', () async {
    final c = ProviderContainer(
      overrides: [
        sourcePluginRunnerProvider.overrideWithValue(null),
        ...onlineOverrides(testRecords(const AsyncData([]))),
      ],
    );
    addTearDown(c.dispose);
    await controllerOf(c).search(sourceId, 'x');

    expect((stateOf(c) as OnlineSearchFailed).kind, SourceFailureKind.internal);
  });
}
