import 'package:material_ui/material_ui.dart' show FilterChip, Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/navigation_history.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import 'package:kanaru/features/lyrics_plugin_store/lyrics_plugin_store_routes.dart';
import 'package:kanaru/features/lyrics_plugin_store/plugin_store_page.dart';
import 'package:kanaru/features/lyrics_sources/lyrics_sources_page.dart';
import 'package:kanaru/features/lyrics_sources/lyrics_sources_routes.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:kanaru/shared/translation_plugin_routes.dart';

import '../lyrics_plugin_store/store_test_harness.dart' as store;
import 'lyrics_sources_harness.dart';

/// The path a [RouteBase] list joins to, one branch deep, under [parent].
List<String> _joined(String parent, List<RouteBase> routes) => [
  for (final route in routes)
    if (route is GoRoute) ...[
      '$parent/${route.path}',
      ..._joined('$parent/${route.path}', route.routes),
    ],
];

void main() {
  final repo = store.repoOf(
    store.repoA,
    'Kho A',
    entries: [store.entryOf('plain', name: 'Plain', version: 7)],
  );

  Future<GoRouter> pump(WidgetTester tester, {String? location}) => pumpSources(
    tester,
    plugins: FakePlugins(),
    withStore: true,
    location: location ?? lyricsSourcesRoute,
    overrides: [
      pluginStoreRawInputProvider.overrideWith(
        (ref) => AsyncData(
          PluginStoreInput(records: const [], repos: [repo], available: true),
        ),
      ),
      lyricsPluginReposProvider.overrideWith((ref) => Stream.value([repo])),
      lyricsPluginReposControllerProvider.overrideWithValue(
        store.FakeRepos()..catalog = [repo],
      ),
    ],
  );

  test('the nested paths join to the shared constants', () {
    final paths = [
      ..._joined(
        settingsPlaybackRoute,
        lyricsSourcesRoutesWith(children: [lyricsSourcesStoreMount()]),
      ),
      ..._joined(settingsRoute, [lyricsRootStoreMount()]),
      ..._joined(settingsPlaybackRoute, [
        ...translationPluginRoutes(),
        translationStoreMount(),
      ]),
    ];
    expect(
      paths,
      containsAll([
        lyricsSourcesRoute,
        lyricsPluginRoutePattern,
        for (final base in [lyricsStoreRoute, lyricsSourcesStoreRoute]) ...[
          base,
          lyricsStoreRepositoriesRoute(base),
          lyricsStoreItemRoutePatternAt(base),
        ],
        translationPluginsRoute,
        translationPluginRoutePattern,
        lyricsStoreRepositoriesRoute(translationPluginsRoute),
        lyricsStoreItemRoutePatternAt(translationPluginsRoute),
      ]),
    );
  });

  testWidgets('the Get more plugins row opens the store', (tester) async {
    final router = await pump(tester);
    await tester.tap(find.text(en.lyricsSourcesGetMore));
    await tester.pumpAndSettle();
    expect(find.byType(PluginStorePage), findsOneWidget);
    expect(router.state.uri.path, lyricsSourcesStoreRoute);
  });

  testWidgets('shell back walks Sources, Store, Item and Repositories', (
    tester,
  ) async {
    final router = await pump(tester);
    final container = ProviderContainer(
      overrides: [routerProvider.overrideWithValue(router)],
    );
    addTearDown(container.dispose);
    final history = container.read(navigationHistoryProvider.notifier);
    String here() => router.state.uri.path;

    await tester.tap(find.text(en.lyricsSourcesGetMore));
    await tester.pumpAndSettle();
    expect(here(), lyricsSourcesStoreRoute);

    await tester.tap(find.text('Plain'));
    await tester.pumpAndSettle();
    expect(here(), lyricsStoreItemRoutePatternAt(lyricsSourcesStoreRoute));

    history.back();
    await tester.pumpAndSettle();
    expect(here(), lyricsSourcesStoreRoute);
    expect(find.byType(PluginStorePage), findsOneWidget);

    await tester.tap(find.byTooltip('Show menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.lyricsStoreMenuRepositories(1)));
    await tester.pumpAndSettle();
    expect(here(), lyricsStoreRepositoriesRoute(lyricsSourcesStoreRoute));

    history.back();
    await tester.pumpAndSettle();
    expect(here(), lyricsSourcesStoreRoute);
    history.back();
    await tester.pumpAndSettle();
    expect(here(), lyricsSourcesRoute);
    expect(find.byType(LyricsSourcesPage), findsOneWidget);
  });

  testWidgets('back from the store pops to the same sources page', (
    tester,
  ) async {
    final router = await pump(tester);
    final container = ProviderContainer(
      overrides: [routerProvider.overrideWithValue(router)],
    );
    addTearDown(container.dispose);
    final history = container.read(navigationHistoryProvider.notifier);
    final before = tester.state(find.byType(LyricsSourcesPage));

    await tester.tap(find.text(en.lyricsSourcesGetMore));
    await tester.pumpAndSettle();
    history.back();
    await tester.pumpAndSettle();

    expect(tester.state(find.byType(LyricsSourcesPage)), same(before));
  });

  group('root mount', () {
    testWidgets('back from an item pops to the same store page', (
      tester,
    ) async {
      final router = await pump(tester, location: lyricsStoreRoute);
      final container = ProviderContainer(
        overrides: [routerProvider.overrideWithValue(router)],
      );
      addTearDown(container.dispose);
      final history = container.read(navigationHistoryProvider.notifier);
      final before = tester.state(find.byType(PluginStorePage));

      await tester.tap(find.text('Plain'));
      await tester.pumpAndSettle();
      history.back();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, lyricsStoreRoute);
      expect(tester.state(find.byType(PluginStorePage)), same(before));
      expect(find.byType(LyricsSourcesPage), findsNothing);
    });

    testWidgets('back from the store lands on the settings root', (
      tester,
    ) async {
      final router = await pump(tester, location: settingsRoute);
      final container = ProviderContainer(
        overrides: [routerProvider.overrideWithValue(router)],
      );
      addTearDown(container.dispose);
      final history = container.read(navigationHistoryProvider.notifier);
      expect(find.text('settings page'), findsOneWidget);

      router.go(lyricsStoreRoute);
      await tester.pumpAndSettle();
      expect(find.byType(PluginStorePage), findsOneWidget);
      history.back();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, settingsRoute);
      expect(find.text('settings page'), findsOneWidget);
    });

    testWidgets('the store opens at /settings/plugins', (tester) async {
      final router = await pump(tester, location: lyricsStoreRoute);
      expect(find.byType(PluginStorePage), findsOneWidget);
      expect(router.state.uri.path, lyricsStoreRoute);
    });

    testWidgets('item and repositories stay under the root mount', (
      tester,
    ) async {
      final router = await pump(tester, location: lyricsStoreRoute);
      await tester.tap(find.text('Plain'));
      await tester.pumpAndSettle();
      expect(
        router.state.uri.path,
        lyricsStoreItemRoutePatternAt(lyricsStoreRoute),
      );
      expect(find.text('Kho A'), findsOneWidget);

      router.go(lyricsStoreRoute);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.lyricsStoreMenuRepositories(1)));
      await tester.pumpAndSettle();
      expect(
        router.state.uri.path,
        lyricsStoreRepositoriesRoute(lyricsStoreRoute),
      );
    });
  });

  testWidgets('the repositories route shows the repository list', (
    tester,
  ) async {
    await pump(
      tester,
      location: lyricsStoreRepositoriesRoute(lyricsSourcesStoreRoute),
    );
    expect(find.text(en.lyricsStoreReposTitle), findsWidgets);
    expect(find.text('Kho A'), findsOneWidget);
  });

  testWidgets('the item route shows the entry named by its query', (
    tester,
  ) async {
    await pump(
      tester,
      location: lyricsStoreItemRoute(
        base: lyricsSourcesStoreRoute,
        repoUrl: store.repoA,
        slug: 'plain',
      ),
    );
    expect(find.text('Plain'), findsWidgets);
    expect(find.text('Kho A'), findsOneWidget);
  });

  testWidgets('an item route without its query shows not found', (
    tester,
  ) async {
    await pump(
      tester,
      location: lyricsStoreItemRoutePatternAt(lyricsSourcesStoreRoute),
    );
    expect(tester.takeException(), isNull);
    expect(find.text(en.lyricsStoreItemNotFound), findsOneWidget);
  });

  testWidgets('an item route missing only the slug shows not found', (
    tester,
  ) async {
    await pump(
      tester,
      location:
          '${lyricsStoreItemRoutePatternAt(lyricsSourcesStoreRoute)}?$lyricsStoreItemRepoParam=${Uri.encodeQueryComponent(store.repoA)}',
    );
    expect(tester.takeException(), isNull);
    expect(find.text(en.lyricsStoreItemNotFound), findsOneWidget);
  });

  testWidgets('an item route missing only the repo shows not found', (
    tester,
  ) async {
    await pump(
      tester,
      location:
          '${lyricsStoreItemRoutePatternAt(lyricsSourcesStoreRoute)}?$lyricsStoreItemSlugParam=plain',
    );
    expect(tester.takeException(), isNull);
    expect(find.text(en.lyricsStoreItemNotFound), findsOneWidget);
  });

  testWidgets('an item route with an unknown slug shows not found', (
    tester,
  ) async {
    await pump(
      tester,
      location: lyricsStoreItemRoute(
        base: lyricsSourcesStoreRoute,
        repoUrl: store.repoA,
        slug: 'nope',
      ),
    );
    expect(find.text(en.lyricsStoreItemNotFound), findsOneWidget);
  });

  group('kind per mount', () {
    final tr = store.entryOf('tr', name: 'TrNew', kind: PluginKind.translate);
    final lyr = store.entryOf('lyr', name: 'LyrNew');
    final mixed = store.repoOf(store.repoA, 'Kho A', entries: [lyr, tr]);
    final records = [
      testRecord(idA, name: 'LyrFile'),
      testRecord(idB, name: 'TrFile', pluginKind: PluginKind.translate),
    ];

    Future<GoRouter> pumpMixed(
      WidgetTester tester,
      String location,
    ) => pumpSources(
      tester,
      records: records,
      plugins: FakePlugins(),
      withStore: true,
      location: location,
      overrides: [
        pluginStoreRawInputProvider.overrideWith(
          (ref) => AsyncData(
            PluginStoreInput(records: records, repos: [mixed], available: true),
          ),
        ),
        lyricsPluginReposProvider.overrideWith((ref) => Stream.value([mixed])),
        lyricsPluginReposControllerProvider.overrideWithValue(
          store.FakeRepos()..catalog = [mixed],
        ),
      ],
    );

    testWidgets('the lyrics mounts start on all kinds', (tester) async {
      for (final base in [lyricsStoreRoute, lyricsSourcesStoreRoute]) {
        await pumpMixed(tester, base);
        expect(find.text('LyrNew'), findsOneWidget, reason: base);
        expect(find.text('TrNew'), findsOneWidget, reason: base);
      }
    });

    testWidgets('the translation mount starts on Translate', (tester) async {
      await pumpMixed(tester, translationPluginsRoute);
      expect(find.text('TrNew'), findsOneWidget);
      expect(find.text('TrFile'), findsOneWidget);
      expect(find.text('LyrNew'), findsNothing);
    });

    testWidgets('a kind query preselects that kind in a lyrics mount', (
      tester,
    ) async {
      await pumpMixed(
        tester,
        lyricsStoreRouteWithKind(lyricsSourcesStoreRoute, 'lyrics'),
      );
      expect(find.text('LyrNew'), findsOneWidget);
      expect(find.text('TrNew'), findsNothing);
    });

    testWidgets('the kind survives an item page and back', (tester) async {
      final router = await pumpMixed(
        tester,
        lyricsStoreRouteWithKind(lyricsSourcesStoreRoute, 'lyrics'),
      );
      final container = ProviderContainer(
        overrides: [routerProvider.overrideWithValue(router)],
      );
      addTearDown(container.dispose);
      final history = container.read(navigationHistoryProvider.notifier);

      await tester.tap(find.text('LyrNew'));
      await tester.pumpAndSettle();
      history.back();
      await tester.pumpAndSettle();

      expect(find.text('LyrNew'), findsOneWidget);
      expect(find.text('TrNew'), findsNothing);
    });

    testWidgets('Get more plugins still lists every kind', (tester) async {
      await pumpMixed(tester, lyricsSourcesRoute);
      await tester.tap(find.text(en.lyricsSourcesGetMore));
      await tester.pumpAndSettle();
      expect(find.text('LyrNew'), findsOneWidget);
      expect(find.text('TrNew'), findsOneWidget);
    });

    testWidgets('an unknown kind query is ignored', (tester) async {
      await pumpMixed(
        tester,
        lyricsStoreRouteWithKind(lyricsSourcesStoreRoute, 'nope'),
      );
      expect(find.text('LyrNew'), findsOneWidget);
      expect(find.text('TrNew'), findsOneWidget);
    });

    testWidgets('filter picks do not carry over between mounts', (
      tester,
    ) async {
      Future<void> pick(String label) async {
        await tester.tap(find.byIcon(AppIcons.filter));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is FilterChip &&
                w.label is Text &&
                ((w.label as Text).textSpan?.toPlainText() ??
                        (w.label as Text).data ??
                        '')
                    .startsWith(label),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.lyricsStoreFilterDone));
        await tester.pumpAndSettle();
      }

      final router = await pumpMixed(tester, lyricsSourcesStoreRoute);
      await pick(en.lyricsStoreKindLyrics);
      expect(find.text('LyrNew'), findsOneWidget);
      expect(find.text('TrNew'), findsNothing);

      // The translation mount starts on Translate, not on the Lyrics pick.
      router.go(translationPluginsRoute);
      await tester.pumpAndSettle();
      expect(find.text('LyrNew'), findsNothing);
      expect(find.text('TrNew'), findsOneWidget);
      await tester.tap(find.byIcon(AppIcons.filter));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilterChip, en.lyricsStoreChipAll).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.lyricsStoreFilterDone));
      await tester.pumpAndSettle();
      expect(find.text('LyrNew'), findsOneWidget);

      // Back in a lyrics mount nothing is picked.
      router.go(lyricsSourcesStoreRoute);
      await tester.pumpAndSettle();
      expect(find.text('LyrNew'), findsOneWidget);
      expect(find.text('TrNew'), findsOneWidget);
    });

    testWidgets('an installed row opens the page of its kind', (tester) async {
      final router = await pumpMixed(tester, translationPluginsRoute);
      await tester.tap(find.text('TrFile'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, translationPluginRoute(idB));

      router.go(lyricsSourcesStoreRoute);
      await tester.pumpAndSettle();
      await tester.tap(find.text('LyrFile'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, lyricsPluginRoute(idA));
    });

    testWidgets('Open on a catalog item page goes to the page of its kind', (
      tester,
    ) async {
      final installedTr = store.recordOf(
        idB,
        name: 'TrNew',
        repoUrl: store.repoA,
        repoSlug: 'tr',
        kind: PluginKind.translate,
      );
      final repoRecords = [installedTr];
      final router = await pumpSources(
        tester,
        records: repoRecords,
        plugins: FakePlugins(),
        withStore: true,
        location: lyricsStoreItemRoute(
          base: translationPluginsRoute,
          repoUrl: store.repoA,
          slug: 'tr',
        ),
        overrides: [
          pluginStoreRawInputProvider.overrideWith(
            (ref) => AsyncData(
              PluginStoreInput(
                records: repoRecords,
                repos: [mixed],
                available: true,
              ),
            ),
          ),
          lyricsPluginReposProvider.overrideWith(
            (ref) => Stream.value([mixed]),
          ),
          lyricsPluginReposControllerProvider.overrideWithValue(
            store.FakeRepos()..catalog = [mixed],
          ),
        ],
      );
      await tester.tap(find.text(en.lyricsStoreItemOpenInstalled));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, translationPluginRoute(idB));
    });

    testWidgets('an item opened from the translation mount stays in it', (
      tester,
    ) async {
      final router = await pumpMixed(tester, translationPluginsRoute);
      await tester.tap(find.text('TrNew'));
      await tester.pumpAndSettle();
      expect(
        router.state.uri.path,
        lyricsStoreItemRoutePatternAt(translationPluginsRoute),
      );
    });
  });
}
