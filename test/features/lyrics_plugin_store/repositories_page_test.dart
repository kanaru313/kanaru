import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';
import 'package:kanaru/features/lyrics_plugin_store/repositories_page.dart';
import 'package:material_ui/material_ui.dart';

import 'store_test_harness.dart';

void main() {
  group('list', () {
    testWidgets('shows name, address and a trash can per repository', (
      tester,
    ) async {
      await pumpStore(
        tester,
        const RepositoriesPage(),
        repos: [repoOf(repoA, 'Kho A'), repoOf(repoB, 'Kho B')],
      );
      expect(find.text('Kho A'), findsOneWidget);
      expect(find.text(repoB), findsOneWidget);
      expect(find.byTooltip('Remove repository'), findsNWidgets(2));
    });

    testWidgets('marks a repository whose last fetch failed', (tester) async {
      await pumpStore(
        tester,
        const RepositoriesPage(),
        repos: [
          repoOf(repoA, 'Kho A'),
          repoOf(
            repoB,
            'Kho B',
            error: const RepoLoadError(RepoFetchErrorKind.network),
          ),
        ],
      );
      expect(find.text('!'), findsOneWidget);
      expect(
        find.byTooltip('The last load failed: network error'),
        findsOneWidget,
      );
    });

    testWidgets('says so when there is no repository', (tester) async {
      await pumpStore(tester, const RepositoriesPage());
      expect(find.text('No repositories yet.'), findsOneWidget);
    });

    testWidgets('says so when the plugin feature is unavailable', (
      tester,
    ) async {
      await pumpStore(tester, const RepositoriesPage(), available: false);
      expect(
        find.text('The plugin store is not available right now.'),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('the add button has a tooltip and a semantic label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpStore(tester, const RepositoriesPage());
      expect(find.byTooltip('Add repository'), findsOneWidget);
      expect(find.bySemanticsLabel('Add repository'), findsWidgets);
      handle.dispose();
    });

    testWidgets('the add button never covers the last trash can', (
      tester,
    ) async {
      await pumpStore(
        tester,
        const RepositoriesPage(),
        size: const Size(800, 500),
        repos: [
          for (var i = 0; i < 12; i++)
            repoOf('https://r$i.example.com/p.json', 'Kho $i'),
        ],
      );
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      final last = find.byTooltip('Remove repository').last;
      expect(last.hitTestable(), findsOneWidget);
      final fab = tester.getRect(find.byType(FloatingActionButton));
      expect(tester.getRect(last).overlaps(fab), isFalse);
    });
  });

  group('remove', () {
    testWidgets('asks, then removes', (tester) async {
      final fake = FakeRepos();
      await pumpStore(
        tester,
        const RepositoriesPage(),
        repos: [repoOf(repoA, 'Kho A')],
        reposController: fake,
      );
      await tester.tap(find.byTooltip('Remove repository'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Kho A?'), findsOneWidget);
      expect(
        find.text(
          'Plugins installed from this repository stay, but will no longer get updates.',
        ),
        findsOneWidget,
      );
      expect(fake.removed, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(fake.removed, [repoA]);
      expect(find.text('Removed Kho A'), findsOneWidget);
    });

    testWidgets('Vietnamese texts follow the mockup', (tester) async {
      await pumpStore(
        tester,
        const RepositoriesPage(),
        locale: const Locale('vi'),
        repos: [repoOf(repoA, 'Kho A')],
      );
      await tester.tap(find.byTooltip('Gỡ repository'));
      await tester.pumpAndSettle();
      expect(find.text('Gỡ Kho A?'), findsOneWidget);
      expect(
        find.text(
          'Plugin đã cài từ repository này vẫn được giữ, nhưng sẽ không còn nhận cập nhật.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cancel keeps it', (tester) async {
      final fake = FakeRepos();
      await pumpStore(
        tester,
        const RepositoriesPage(),
        repos: [repoOf(repoA, 'Kho A')],
        reposController: fake,
      );
      await tester.tap(find.byTooltip('Remove repository'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.removed, isEmpty);
    });
  });

  group('add dialog', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester, String url) async {
      await tester.enterText(find.byType(TextField), url);
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
    }

    final errors = <AddRepoFailed, String>{
      const AddRepoFailed(AddRepoFailure.publicNeedsHttps):
          'A public address needs https',
      const AddRepoFailed(AddRepoFailure.invalidUrl): 'Invalid URL',
      const AddRepoFailed(AddRepoFailure.duplicate):
          'This repository is already added',
      const AddRepoFailed(AddRepoFailure.network):
          'Could not load the list: network error',
      const AddRepoFailed(AddRepoFailure.notFound):
          'No plugin list was found at this address',
      const AddRepoFailed(AddRepoFailure.badFormat):
          'The file is not a valid plugin list',
      const AddRepoFailed(AddRepoFailure.blockedAddress):
          'This address is blocked',
      const AddRepoFailed(
        AddRepoFailure.blockedAddress,
        addressProblem: RepoAddressProblem.localFromPublic,
      ): 'This address is blocked: a public repository must not point to a local address',
      const AddRepoFailed(AddRepoFailure.storage):
          'Could not save the repository',
    };

    for (final entry in errors.entries) {
      testWidgets('shows "${entry.value}" under the field and stays open', (
        tester,
      ) async {
        final fake = FakeRepos()..addResult = entry.key;
        await pumpStore(
          tester,
          const RepositoriesPage(),
          reposController: fake,
        );
        await openDialog(tester);
        await submit(tester, 'https://x.example.com/p.json');
        expect(find.text(entry.value), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        // Editing the field clears the error.
        await tester.enterText(find.byType(TextField), 'https://y');
        await tester.pump();
        expect(find.text(entry.value), findsNothing);
      });
    }

    test('every add failure is covered above', () {
      for (final failure in AddRepoFailure.values) {
        expect(errors.keys.any((e) => e.failure == failure), isTrue);
      }
    });

    testWidgets('shows progress and disables Add while adding', (tester) async {
      final gate = Completer<void>();
      final fake = FakeRepos()..addGate = gate;
      await pumpStore(tester, const RepositoriesPage(), reposController: fake);
      await openDialog(tester);
      await tester.enterText(find.byType(TextField), 'https://x/p.json');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump();
      expect(find.text('Loading…'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(fake.adds, ['https://x/p.json']);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('success closes the dialog and says how many plugins', (
      tester,
    ) async {
      final fake = FakeRepos();
      await pumpStore(tester, const RepositoriesPage(), reposController: fake);
      await openDialog(tester);
      await submit(tester, 'https://x.example.com/p.json');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Added Kho · 4 plugins'), findsOneWidget);
    });

    testWidgets('has only a URL field and two buttons', (tester) async {
      await pumpStore(tester, const RepositoriesPage());
      await openDialog(tester);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
