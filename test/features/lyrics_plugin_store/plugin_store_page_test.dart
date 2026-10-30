import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_repo.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';
import 'package:kanaru/features/lyrics_plugin_store/plugin_store_page.dart';

import 'store_test_harness.dart';

class _Taps {
  final installed = <String>[];
  final items = <(String, String)>[];
  int repositories = 0;

  Widget page() => PluginStorePage(
    onOpenInstalled: installed.add,
    onOpenCatalogItem: (repo, slug) => items.add((repo, slug)),
    onOpenRepositories: () => repositories++,
  );
}

void main() {
  final repo = repoOf(
    repoA,
    'Kho A',
    entries: [
      entryOf('fresh', name: 'Fresh', version: 5),
      entryOf('old', name: 'Old', version: 4),
      entryOf('plain', name: 'Plain'),
      entryOf('future', name: 'Future', apiVersion: 99),
    ],
  );
  final records = [
    recordOf(
      'plugin-fresh',
      name: 'Fresh',
      version: 3,
      repoUrl: repoA,
      repoSlug: 'fresh',
      sourceName: 'Kho A',
    ),
    recordOf(
      'plugin-old',
      name: 'Old',
      version: 4,
      repoUrl: repoA,
      repoSlug: 'old',
      sourceName: 'Kho A',
    ),
    recordOf('plugin-file', name: 'FromZip'),
  ];

  testWidgets('opening the store refreshes every repository once', (
    tester,
  ) async {
    final fake = FakeRepos();
    await pumpStore(
      tester,
      _Taps().page(),
      repos: [repo],
      reposController: fake,
    );
    expect(fake.refreshAllCalls, 1);
  });

  testWidgets('shows the three sections with counts and the footer', (
    tester,
  ) async {
    await pumpStore(tester, _Taps().page(), repos: [repo], records: records);
    expect(find.text('Updates (1)'), findsOneWidget);
    expect(find.text('Installed (2)'), findsOneWidget);
    expect(find.text('Not installed (1)'), findsOneWidget);
    expect(find.text('Update all'), findsOneWidget);
    expect(find.text('1 plugin needs a newer Kanaru'), findsOneWidget);
    expect(find.text('Plain'), findsOneWidget);
    // The repository name, or "From file", is the subtitle.
    expect(find.text('Kho A'), findsNWidgets(4)); // 3 rows + chip
    expect(find.text('From file'), findsWidgets);
  });

  testWidgets('empty sections and the footer are hidden', (tester) async {
    final onlyInstalled = repoOf(repoA, 'Kho A', entries: [entryOf('old')]);
    await pumpStore(
      tester,
      _Taps().page(),
      repos: [onlyInstalled],
      records: [
        recordOf(
          'plugin-old',
          name: 'old',
          version: 3,
          repoUrl: repoA,
          repoSlug: 'old',
        ),
      ],
    );
    expect(find.textContaining('Updates ('), findsNothing);
    expect(find.textContaining('Not installed ('), findsNothing);
    expect(find.textContaining('newer Kanaru'), findsNothing);
    expect(find.text('Installed (1)'), findsOneWidget);
  });

  testWidgets('chips show only with two or more sources', (tester) async {
    await pumpStore(tester, _Taps().page(), repos: [repo], records: records);
    // One repository plus a file plugin: two sources.
    expect(find.byType(ChoiceChip), findsNWidgets(3));
  });

  testWidgets('no chips with a single source', (tester) async {
    await pumpStore(tester, _Taps().page(), repos: [repo]);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('a chip narrows the list to its source', (tester) async {
    final other = repoOf(repoB, 'Kho B', entries: [entryOf('b1', name: 'Bee')]);
    await pumpStore(tester, _Taps().page(), repos: [repo, other]);
    expect(find.text('Bee'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Kho A'));
    await tester.pumpAndSettle();
    expect(find.text('Bee'), findsNothing);
    expect(find.text('Plain'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('Bee'), findsOneWidget);
  });

  testWidgets('search narrows the list', (tester) async {
    await pumpStore(tester, _Taps().page(), repos: [repo], records: records);
    await tester.enterText(find.byType(TextField), 'plain');
    await tester.pumpAndSettle();
    expect(find.text('Plain'), findsOneWidget);
    expect(find.text('Fresh'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matching plugins.'), findsOneWidget);
  });

  group('banner', () {
    testWidgets('hidden when no repository failed', (tester) async {
      await pumpStore(tester, _Taps().page(), repos: [repo]);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('one failing repository names it and retries it', (
      tester,
    ) async {
      final fake = FakeRepos();
      final failing = repoOf(
        repoA,
        'Kho A',
        entries: [entryOf('plain')],
        error: const RepoLoadError(RepoFetchErrorKind.network),
      );
      await pumpStore(
        tester,
        _Taps().page(),
        repos: [failing],
        reposController: fake,
      );
      expect(find.text('Could not load Kho A: network error'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(fake.refreshed, [repoA]);
    });

    testWidgets('several failing repositories show a count and retry all', (
      tester,
    ) async {
      final fake = FakeRepos();
      const error = RepoLoadError(RepoFetchErrorKind.notFound);
      await pumpStore(
        tester,
        _Taps().page(),
        repos: [
          repoOf(repoA, 'Kho A', entries: [entryOf('a')], error: error),
          repoOf(repoB, 'Kho B', entries: [entryOf('b')], error: error),
        ],
        reposController: fake,
      );
      expect(find.text('2 repositories could not be loaded'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      // Once when the page opened, once for the retry.
      expect(fake.refreshAllCalls, 2);
    });

    testWidgets('texts are Vietnamese in the Vietnamese locale', (
      tester,
    ) async {
      const error = RepoLoadError(RepoFetchErrorKind.network);
      await pumpStore(
        tester,
        _Taps().page(),
        locale: const Locale('vi'),
        repos: [
          repoOf(repoA, 'Kho A', entries: [entryOf('a')], error: error),
        ],
      );
      expect(find.text('Không tải được Kho A: lỗi mạng'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Kho plugin'), findsOneWidget);
    });
  });

  group('empty state', () {
    testWidgets('offers adding a repository and installing a file', (
      tester,
    ) async {
      await pumpStore(tester, _Taps().page());
      expect(find.text('No plugins yet'), findsOneWidget);
      expect(find.text('Add repository'), findsOneWidget);
      expect(find.text('Install from file…'), findsOneWidget);
      await tester.tap(find.text('Add repository'));
      await tester.pumpAndSettle();
      // The add dialog opens straight away.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('is not shown when only a repository exists', (tester) async {
      await pumpStore(tester, _Taps().page(), repos: [repoOf(repoA, 'Kho A')]);
      expect(find.text('No plugins yet'), findsNothing);
    });
  });

  testWidgets('says so when the plugin feature is unavailable', (tester) async {
    await pumpStore(tester, _Taps().page(), available: false);
    expect(
      find.text('The plugin store is not available right now.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Show menu'), findsNothing);
  });

  testWidgets('row taps call the callbacks', (tester) async {
    final taps = _Taps();
    await pumpStore(tester, taps.page(), repos: [repo], records: records);
    await tester.tap(find.text('Fresh'));
    await tester.tap(find.text('Plain'));
    expect(taps.installed, ['plugin-fresh']);
    expect(taps.items, [(repoA, 'plain')]);
  });

  testWidgets('every icon button has a tooltip and a semantic label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpStore(tester, _Taps().page(), repos: [repo], records: records);
    for (final label in ['Update', 'Uninstall plugin', 'Install']) {
      expect(find.byTooltip(label), findsWidgets);
      expect(find.bySemanticsLabel(label), findsWidgets);
    }
    handle.dispose();
  });

  group('menu', () {
    testWidgets('opens the repositories with their count', (tester) async {
      final taps = _Taps();
      await pumpStore(tester, taps.page(), repos: [repo]);
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      expect(find.text('Repositories (1)'), findsOneWidget);
      expect(find.byType(PopupMenuDivider), findsOneWidget);
      await tester.tap(find.text('Repositories (1)'));
      await tester.pumpAndSettle();
      expect(taps.repositories, 1);
    });

    testWidgets('refresh all fetches again', (tester) async {
      final fake = FakeRepos();
      await pumpStore(
        tester,
        _Taps().page(),
        repos: [repo],
        reposController: fake,
      );
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh all'));
      await tester.pumpAndSettle();
      expect(fake.refreshAllCalls, 2);
    });
  });
}
