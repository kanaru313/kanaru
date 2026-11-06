import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/core/sources/source_plugin_records.dart';
import 'package:kanaru/core/sources/source_plugin_runner.dart';
import 'package:kanaru/features/online_sources/online_sources_screen.dart';
import 'package:kanaru/features/online_sources/online_state_views.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:kanaru/shared/online_routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import 'online_test_support.dart';

AppLocalizations get en => lookupAppLocalizations(const Locale('en'));

class OnlineHarness {
  OnlineHarness(this.router, this.container, this.backend, this.records);

  final GoRouter router;
  final ProviderContainer container;
  final FakeAudioBackend backend;

  /// Changes the records the app sees.
  final TestRecords records;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

Future<OnlineHarness> pumpOnline(
  WidgetTester tester, {
  required FakeSourceRunner runner,
  AsyncValue<List<LyricsPluginRecord>>? records,
  Size size = const Size(1000, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = FakeAudioBackend();
  final provider = testRecords(records ?? AsyncValue.data([sourceRecord()]));
  final router = GoRouter(
    initialLocation: onlineRoute,
    routes: [
      GoRoute(
        path: onlineRoute,
        builder: (context, state) =>
            const Scaffold(body: OnlineSourcesScreen()),
        routes: [
          GoRoute(
            path: onlineSourcePluginRoutePattern,
            builder: (context, state) => const Text('plugin page'),
          ),
        ],
      ),
      GoRoute(
        path: lyricsStoreRoute,
        builder: (context, state) => const Text('store page'),
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      ...onlineOverrides(provider),
      sourcePluginRunnerProvider.overrideWithValue(runner),
      audioBackendProvider.overrideWithValue(backend),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return OnlineHarness(
    router,
    container,
    backend,
    container.read(provider.notifier),
  );
}

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.text(en.onlineSearchButton));
  await tester.pumpAndSettle();
}

FakeSourceRunner songs([int count = 3]) =>
    FakeSourceRunner((_, _, _) async => pageOf(count));

FakeSourceRunner failing(SourceFailureKind kind, [String message = '']) =>
    FakeSourceRunner(
      (_, _, _) async => throw SourceFailure(kind: kind, message: message),
    );

void main() {
  group('header', () {
    testWidgets('shows the name, the first plain host and the source button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final h = await pumpOnline(tester, runner: songs());

      expect(find.text('Tube'), findsOneWidget);
      // The wildcard entry comes first but is not the one shown.
      expect(find.text('api.example.com'), findsOneWidget);
      expect(find.text('*.example.com'), findsNothing);
      expect(find.byTooltip(en.onlineSourceTooltip), findsOneWidget);
      expect(find.bySemanticsLabel(en.onlineSourceSemantics('Tube')), findsOne);

      await tester.tap(find.byTooltip(en.onlineSourceTooltip));
      await tester.pumpAndSettle();

      expect(h.location, onlineSourcePluginRoute(sourceId));
      expect(find.text('plugin page'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('has no host line when every host is a wildcard', (
      tester,
    ) async {
      await pumpOnline(
        tester,
        runner: songs(),
        records: AsyncValue.data([
          sourceRecord(hosts: const ['*.example.com']),
        ]),
      );

      expect(find.text('Tube'), findsOneWidget);
      expect(find.textContaining('example.com'), findsNothing);
    });
  });

  group('search', () {
    testWidgets('typing sends nothing; Enter and the button send once each', (
      tester,
    ) async {
      final runner = songs();
      await pumpOnline(tester, runner: runner);
      expect(find.text(en.onlineIdle), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'cat');
      await tester.enterText(find.byType(TextField), 'cats');
      await tester.pumpAndSettle();
      expect(runner.searches, isEmpty);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(runner.searches, ['$sourceId|cats']);

      await tester.tap(find.text(en.onlineSearchButton));
      await tester.pumpAndSettle();
      expect(runner.searches, ['$sourceId|cats', '$sourceId|cats']);
    });

    testWidgets('lists title, artist and length of every result', (
      tester,
    ) async {
      await pumpOnline(tester, runner: songs());
      await search(tester, 'cats');

      expect(find.text('Song 1'), findsOneWidget);
      expect(find.text('Artist 2'), findsOneWidget);
      expect(find.text('3:05'), findsOneWidget);
    });

    testWidgets('shows the empty state', (tester) async {
      await pumpOnline(tester, runner: songs(0));
      await search(tester, 'zzz');

      expect(find.text(en.onlineEmpty('zzz')), findsOneWidget);
    });

    testWidgets('keeps its results when the screen is rebuilt', (tester) async {
      final h = await pumpOnline(tester, runner: songs());
      await search(tester, 'cats');

      h.router.go(lyricsStoreRoute);
      await tester.pumpAndSettle();
      h.router.go(onlineRoute);
      await tester.pumpAndSettle();

      expect(find.text('Song 2'), findsOneWidget);
    });
  });

  testWidgets('a tap queues every shown result and starts at that row', (
    tester,
  ) async {
    final h = await pumpOnline(tester, runner: songs());
    await search(tester, 'cats');

    await tester.tap(find.text('Song 2'));
    await tester.pumpAndSettle();

    final queue = h.container.read(playerServiceProvider).queue;
    expect(queue.original.map((t) => t.title), ['Song 1', 'Song 2', 'Song 3']);
    expect(queue.original.every((t) => t.remote != null), isTrue);
    expect(queue.index, 1);
    expect(h.backend.calls, contains('open(Song 2, next: Song 3)'));
  });

  group('consent', () {
    FakeSourceRunner needsNotice(List<ProviderContainer> holder) =>
        FakeSourceRunner((id, _, _) async {
          final ids = holder.single
              .read(settingsProvider)
              .onlineSources
              .noticeAcknowledged;
          if (!ids.contains(id)) {
            throw const SourceFailure(kind: SourceFailureKind.notConsented);
          }
          return pageOf(2);
        });

    testWidgets('names the plugin and its hosts; Accept runs the search', (
      tester,
    ) async {
      final holder = <ProviderContainer>[];
      final runner = needsNotice(holder);
      final h = await pumpOnline(tester, runner: runner);
      holder.add(h.container);

      await search(tester, 'cats');

      expect(find.text(en.onlineConsentTitle('Tube')), findsOneWidget);
      expect(
        find.text(
          en.onlineConsentBody(
            'Tube',
            '*.example.com, api.example.com, b.test',
          ),
        ),
        findsOneWidget,
      );
      expect(runner.searches, hasLength(1));

      await tester.tap(find.text(en.onlineConsentAccept));
      await tester.pumpAndSettle();

      expect(
        h.container.read(settingsProvider).onlineSources.noticeAcknowledged,
        {sourceId},
      );
      expect(runner.searches, ['$sourceId|cats', '$sourceId|cats']);
      expect(find.text('Song 1'), findsOneWidget);
    });
  });

  group('errors', () {
    testWidgets(
      'say the cause by kind, show the plugin message; Retry runs again',
      (tester) async {
        var fail = true;
        final runner = FakeSourceRunner((_, _, _) async {
          if (fail) {
            throw const SourceFailure(
              kind: SourceFailureKind.rateLimited,
              message: 'quota used',
            );
          }
          return pageOf(1);
        });
        await pumpOnline(tester, runner: runner);
        await search(tester, 'cats');

        expect(find.text(en.onlineErrorRateLimited), findsOneWidget);
        expect(find.text(en.onlineErrorPluginMessage('quota used')), findsOne);

        fail = false;
        await tester.tap(find.text(en.onlineRetry));
        await tester.pumpAndSettle();

        expect(runner.searches, hasLength(2));
        expect(find.text('Song 1'), findsOneWidget);
      },
    );

    testWidgets('every kind has its own words', (tester) async {
      final words = <String>{};
      for (final kind in [
        SourceFailureKind.auth,
        SourceFailureKind.rateLimited,
        SourceFailureKind.unavailable,
        SourceFailureKind.network,
        SourceFailureKind.invalidOutput,
        SourceFailureKind.busy,
        SourceFailureKind.internal,
      ]) {
        await pumpOnline(tester, runner: failing(kind));
        await search(tester, 'x');
        final text = onlineFailureText(en, kind);
        expect(find.text(text), findsOneWidget, reason: '$kind');
        words.add(text);
      }
      expect(words, hasLength(7));
    });

    testWidgets('a missing setting opens the plugin page', (tester) async {
      final h = await pumpOnline(
        tester,
        runner: failing(SourceFailureKind.needsConfig),
      );
      await search(tester, 'x');

      expect(find.text(en.pluginNeedsConfigTitle('Tube')), findsOneWidget);
      expect(find.text(en.onlineRetry), findsNothing);

      await tester.tap(find.text(en.pluginOpenConfig));
      await tester.pumpAndSettle();

      expect(h.location, onlineSourcePluginRoute(sourceId));
    });
  });

  group('no plugin', () {
    testWidgets('says so and the button opens the plugin store', (
      tester,
    ) async {
      final h = await pumpOnline(
        tester,
        runner: songs(),
        records: const AsyncValue.data([]),
      );

      expect(find.text(en.navOnline), findsOneWidget);
      expect(find.text(en.onlineNoPluginBody), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text(en.onlineNoPluginStore));
      await tester.pumpAndSettle();

      expect(h.location, lyricsStoreRoute);
    });

    testWidgets('shows it after the last source plugin is gone', (
      tester,
    ) async {
      final h = await pumpOnline(tester, runner: songs());
      expect(find.byType(TextField), findsOneWidget);

      h.records.set(const AsyncValue.data([]));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text(en.onlineNoPluginStore), findsOneWidget);
    });
  });

  testWidgets('fits a narrow window', (tester) async {
    await pumpOnline(tester, runner: songs(), size: const Size(360, 700));
    await search(tester, 'cats');

    expect(find.text('Song 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
