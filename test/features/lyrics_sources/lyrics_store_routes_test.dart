import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/app/shell/navigation_history.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import 'package:kanaru/features/lyrics_plugin_store/lyrics_plugin_store_routes.dart';
import 'package:kanaru/features/lyrics_plugin_store/plugin_store_page.dart';
import 'package:kanaru/features/lyrics_sources/lyrics_sources_page.dart';
import 'package:kanaru/features/lyrics_sources/lyrics_sources_routes.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';

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
    final paths = _joined(
      '/settings',
      lyricsSourcesRoutesWith(children: lyricsStoreRoutes),
    );
    expect(
      paths,
      containsAll([
        lyricsSourcesRoute,
        lyricsPluginRoutePattern,
        lyricsStoreRoute,
        lyricsStoreRepositoriesRoute,
        lyricsStoreItemRoutePattern,
      ]),
    );
  });

  testWidgets('the Plugin store button opens the store', (tester) async {
    final router = await pump(tester);
    await tester.tap(find.text(en.lyricsSourcesStore));
    await tester.pumpAndSettle();
    expect(find.byType(PluginStorePage), findsOneWidget);
    expect(router.state.uri.path, lyricsStoreRoute);
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

    await tester.tap(find.text(en.lyricsSourcesStore));
    await tester.pumpAndSettle();
    expect(here(), lyricsStoreRoute);

    await tester.tap(find.text('Plain'));
    await tester.pumpAndSettle();
    expect(here(), lyricsStoreItemRoutePattern);

    history.back();
    await tester.pumpAndSettle();
    expect(here(), lyricsStoreRoute);
    expect(find.byType(PluginStorePage), findsOneWidget);

    await tester.tap(find.byTooltip('Show menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.lyricsStoreMenuRepositories(1)));
    await tester.pumpAndSettle();
    expect(here(), lyricsStoreRepositoriesRoute);

    history.back();
    await tester.pumpAndSettle();
    expect(here(), lyricsStoreRoute);
    history.back();
    await tester.pumpAndSettle();
    expect(here(), lyricsSourcesRoute);
    expect(find.byType(LyricsSourcesPage), findsOneWidget);
  });

  testWidgets('the repositories route shows the repository list', (
    tester,
  ) async {
    await pump(tester, location: lyricsStoreRepositoriesRoute);
    expect(find.text(en.lyricsStoreReposTitle), findsWidgets);
    expect(find.text('Kho A'), findsOneWidget);
  });

  testWidgets('the item route shows the entry named by its query', (
    tester,
  ) async {
    await pump(
      tester,
      location: lyricsStoreItemRoute(repoUrl: store.repoA, slug: 'plain'),
    );
    expect(find.text('Plain'), findsWidgets);
    expect(find.text('Kho A'), findsOneWidget);
  });

  testWidgets('an item route without its query shows not found', (
    tester,
  ) async {
    await pump(tester, location: lyricsStoreItemRoutePattern);
    expect(tester.takeException(), isNull);
    expect(find.text(en.lyricsStoreItemNotFound), findsOneWidget);
  });

  testWidgets('an item route missing only the slug shows not found', (
    tester,
  ) async {
    await pump(
      tester,
      location:
          '$lyricsStoreItemRoutePattern?$lyricsStoreItemRepoParam=${Uri.encodeQueryComponent(store.repoA)}',
    );
    expect(tester.takeException(), isNull);
    expect(find.text(en.lyricsStoreItemNotFound), findsOneWidget);
  });

  testWidgets('an item route missing only the repo shows not found', (
    tester,
  ) async {
    await pump(
      tester,
      location: '$lyricsStoreItemRoutePattern?$lyricsStoreItemSlugParam=plain',
    );
    expect(tester.takeException(), isNull);
    expect(find.text(en.lyricsStoreItemNotFound), findsOneWidget);
  });

  testWidgets('an item route with an unknown slug shows not found', (
    tester,
  ) async {
    await pump(
      tester,
      location: lyricsStoreItemRoute(repoUrl: store.repoA, slug: 'nope'),
    );
    expect(find.text(en.lyricsStoreItemNotFound), findsOneWidget);
  });
}
