import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_problem.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_install_outcome.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_failure_text.dart';
import 'package:kanaru/features/lyrics_plugin_store/plugin_store_page.dart';
import 'package:material_ui/material_ui.dart';

import 'store_test_harness.dart';

Widget _page() => PluginStorePage(
  onOpenInstalled: (_) {},
  onOpenCatalogItem: (_, _) {},
  onOpenRepositories: () {},
);

final _repo = repoOf(
  repoA,
  'Kho A',
  entries: [
    entryOf('plain', name: 'Plain', version: 3, hosts: ['music.example.com']),
    entryOf('fresh', name: 'Fresh', version: 5),
  ],
);

final _installedFresh = recordOf(
  'plugin-fresh',
  name: 'Fresh',
  version: 3,
  repoUrl: repoA,
  repoSlug: 'fresh',
  sourceName: 'Kho A',
);

Future<void> _tapInstall(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Install').first);
  await tester.pumpAndSettle();
}

void main() {
  group('install', () {
    testWidgets('installs now and offers Undo', (tester) async {
      final repos = FakeRepos();
      final plugins = FakePlugins();
      await pumpStore(
        tester,
        _page(),
        repos: [_repo],
        reposController: repos,
        plugins: plugins,
      );
      await _tapInstall(tester);
      expect(repos.installs, [(repoA, 'plain')]);
      expect(find.text('Installed plugin-new'), findsNothing);
      expect(find.text('Installed Demo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(plugins.undos, ['plugin-new']);
    });

    testWidgets('a revived plugin also offers Undo', (tester) async {
      final repos = FakeRepos()
        ..installResult = RepoPluginDone(
          recordOf('plugin-new'),
          RepoPluginChange.revived,
        );
      await pumpStore(tester, _page(), repos: [_repo], reposController: repos);
      await _tapInstall(tester);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('an install that turned into an update has no Undo', (
      tester,
    ) async {
      final repos = FakeRepos()
        ..installResult = RepoPluginDone(
          recordOf('plugin-new', name: 'Demo', version: 4),
          RepoPluginChange.updated,
        );
      await pumpStore(tester, _page(), repos: [_repo], reposController: repos);
      await _tapInstall(tester);
      expect(find.text('Undo'), findsNothing);
      expect(find.text('Updated Demo to v4'), findsOneWidget);
    });

    testWidgets('shows a spinner and ignores a second tap while it runs', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repos = FakeRepos()..installGate = gate;
      await pumpStore(tester, _page(), repos: [_repo], reposController: repos);
      await tester.tap(find.byTooltip('Install').first);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Install'), findsOneWidget);
      expect(repos.installs, hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('noNewerVersion is quiet', (tester) async {
      final repos = FakeRepos()
        ..installResult = const RepoPluginFailed(
          RepoPluginFailure.noNewerVersion,
        );
      await pumpStore(tester, _page(), repos: [_repo], reposController: repos);
      await _tapInstall(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    for (final failure in RepoPluginFailure.values.where(
      (f) =>
          f != RepoPluginFailure.noNewerVersion &&
          f != RepoPluginFailure.needsNewerApp &&
          f != RepoPluginFailure.catalogMismatch,
    )) {
      testWidgets('failure ${failure.name} opens the problem dialog', (
        tester,
      ) async {
        final repos = FakeRepos()..installResult = RepoPluginFailed(failure);
        await pumpStore(
          tester,
          _page(),
          repos: [_repo],
          reposController: repos,
        );
        await _tapInstall(tester);
        expect(find.text('Could not install'), findsOneWidget);
        expect(find.text('Plain · Repo: Kho A'), findsOneWidget);
        expect(
          find.text(
            '•  ${repoPluginFailureText(en, RepoPluginFailed(failure))}',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      });
    }

    testWidgets('a rejected package names the problem', (tester) async {
      final repos = FakeRepos()
        ..installResult = const RepoPluginFailed(
          RepoPluginFailure.rejected,
          problem: PluginPackageProblem(
            PluginPackageProblemKind.missingScript,
            detail: 'lyrics.js',
          ),
        );
      await pumpStore(tester, _page(), repos: [_repo], reposController: repos);
      await _tapInstall(tester);
      expect(
        find.text('•  src/lyrics.js is missing from the package'),
        findsOneWidget,
      );
    });

    testWidgets('needsNewerApp opens its own dialog', (tester) async {
      final repos = FakeRepos()
        ..installResult = const RepoPluginFailed(
          RepoPluginFailure.needsNewerApp,
        );
      await pumpStore(tester, _page(), repos: [_repo], reposController: repos);
      await _tapInstall(tester);
      expect(find.text('Needs a newer Kanaru'), findsOneWidget);
    });

    testWidgets('the apiVersion package problem opens the same dialog', (
      tester,
    ) async {
      final repos = FakeRepos()
        ..installResult = const RepoPluginFailed(
          RepoPluginFailure.rejected,
          problem: PluginPackageProblem(PluginPackageProblemKind.needsNewerApp),
        );
      await pumpStore(tester, _page(), repos: [_repo], reposController: repos);
      await _tapInstall(tester);
      expect(find.text('Needs a newer Kanaru'), findsOneWidget);
    });

    testWidgets('a mismatch shows both sides and can refresh and retry', (
      tester,
    ) async {
      final repos = FakeRepos()
        ..installResult = const RepoPluginFailed(
          RepoPluginFailure.catalogMismatch,
          packageDeclared: (
            version: 2,
            hosts: ['music.example.com', 'x.example.com'],
          ),
        );
      await pumpStore(tester, _page(), repos: [_repo], reposController: repos);
      await _tapInstall(tester);
      expect(find.text('Package does not match the list'), findsOneWidget);
      expect(
        find.text(
          '•  The list says version 3, the downloaded package is version 2',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'The list says host music.example.com, the package declares music.example.com, x.example.com',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Refresh & try again'));
      await tester.pumpAndSettle();
      // Opening refreshed everything; the retry refreshes only that repository.
      expect(repos.refreshAllCalls, 1);
      expect(repos.refreshed, [repoA]);
      expect(repos.installs, hasLength(2));
    });
  });

  group('update', () {
    testWidgets('updates one plugin and says the new version', (tester) async {
      final repos = FakeRepos();
      await pumpStore(
        tester,
        _page(),
        repos: [_repo],
        records: [_installedFresh],
        reposController: repos,
      );
      await tester.tap(find.byTooltip('Update'));
      await tester.pumpAndSettle();
      expect(repos.updates, ['plugin-fresh']);
      expect(find.text('Updated Demo to v4'), findsOneWidget);
    });

    testWidgets('a row being updated shows a spinner', (tester) async {
      final repos = FakeRepos();
      await pumpStore(
        tester,
        _page(),
        repos: [_repo],
        records: [_installedFresh],
        reposController: repos,
      );
      repos.setUpdating({'plugin-fresh'});
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Update'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repos.setUpdating({});
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Update'), findsOneWidget);
    });

    testWidgets('update all reports the count', (tester) async {
      final repos = FakeRepos()
        ..updateAllResult = [
          RepoUpdateOutcome(
            'plugin-fresh',
            'Fresh',
            RepoPluginDone(
              recordOf('plugin-fresh', version: 5),
              RepoPluginChange.updated,
            ),
          ),
        ];
      await pumpStore(
        tester,
        _page(),
        repos: [_repo],
        records: [_installedFresh],
        reposController: repos,
      );
      await tester.tap(find.text('Update all'));
      await tester.pumpAndSettle();
      expect(repos.updateAllCalls, 1);
      expect(find.text('Updated 1 plugin'), findsOneWidget);
    });

    testWidgets('update all reports failures too', (tester) async {
      final repos = FakeRepos()
        ..updateAllResult = const [
          RepoUpdateOutcome(
            'plugin-fresh',
            'Fresh',
            RepoPluginFailed(RepoPluginFailure.download),
          ),
        ];
      await pumpStore(
        tester,
        _page(),
        repos: [_repo],
        records: [_installedFresh],
        reposController: repos,
      );
      await tester.tap(find.text('Update all'));
      await tester.pumpAndSettle();
      expect(find.text('Updated 0, 1 failed'), findsOneWidget);
    });
  });

  group('uninstall', () {
    final installed = recordOf('plugin-file', name: 'FromZip');

    testWidgets('asks first, then uninstalls', (tester) async {
      final plugins = FakePlugins();
      await pumpStore(tester, _page(), records: [installed], plugins: plugins);
      await tester.tap(find.byTooltip('Uninstall plugin'));
      await tester.pumpAndSettle();
      expect(find.text('Uninstall FromZip?'), findsOneWidget);
      expect(find.text('Will be deleted'), findsOneWidget);
      expect(plugins.uninstalls, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Uninstall'));
      await tester.pumpAndSettle();
      expect(plugins.uninstalls, ['plugin-file']);
      expect(find.text('Uninstalled FromZip'), findsOneWidget);
    });

    testWidgets('cancel keeps the plugin', (tester) async {
      final plugins = FakePlugins();
      await pumpStore(tester, _page(), records: [installed], plugins: plugins);
      await tester.tap(find.byTooltip('Uninstall plugin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(plugins.uninstalls, isEmpty);
    });
  });

  group('install from file', () {
    Future<void> openMenuItem(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install from file…'));
      await tester.pumpAndSettle();
    }

    testWidgets('installs the picked zip with Undo', (tester) async {
      final plugins = FakePlugins();
      await pumpStore(
        tester,
        _page(),
        repos: [_repo],
        plugins: plugins,
        pickedFile: '/tmp/demo.zip',
      );
      await openMenuItem(tester);
      expect(plugins.files, ['/tmp/demo.zip']);
      expect(find.text('Installed plugin-file'), findsNothing);
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(plugins.undos, ['plugin-file']);
    });

    testWidgets('does nothing when the picker is cancelled', (tester) async {
      final plugins = FakePlugins();
      await pumpStore(tester, _page(), repos: [_repo], plugins: plugins);
      await openMenuItem(tester);
      expect(plugins.files, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a refused package opens the problem dialog', (tester) async {
      final plugins = FakePlugins()
        ..fileResult = const PluginInstallRejected(
          PluginPackageProblem(PluginPackageProblemKind.notZip),
        );
      await pumpStore(
        tester,
        _page(),
        repos: [_repo],
        plugins: plugins,
        pickedFile: '/tmp/genius.zip',
      );
      await openMenuItem(tester);
      expect(find.text('Could not install'), findsOneWidget);
      expect(
        find.text('The file genius.zip is not a valid plugin.'),
        findsOneWidget,
      );
      expect(
        find.text('•  The file is not a readable zip package'),
        findsOneWidget,
      );
    });
  });
}
