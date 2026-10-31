import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_failure_text.dart';
import 'package:kanaru/features/lyrics_plugin_store/plugin_store_actions.dart';
import 'package:kanaru/features/lyrics_plugin_store/plugin_store_page.dart';
import 'package:kanaru/features/lyrics_plugin_store/plugin_store_providers.dart';
import 'package:material_ui/material_ui.dart';

import 'store_test_harness.dart';

Widget _page() => PluginStorePage(
  onOpenInstalled: (_) {},
  onOpenCatalogItem: (_, _) {},
  onOpenRepositories: () {},
);

PluginRepo _repoWith(int plainVersion) => repoOf(
  repoA,
  'Kho A',
  entries: [entryOf('plain', name: 'Plain', version: plainVersion)],
);

final _installedPlain = recordOf(
  'plugin-plain',
  name: 'Plain',
  version: 3,
  repoUrl: repoA,
  repoSlug: 'plain',
  sourceName: 'Kho A',
);

/// Buttons that call the actions directly, so a test can tap twice or close
/// the screen while the work runs.
class _Host extends StatelessWidget {
  const _Host({required this.shown});

  final ValueNotifier<bool> shown;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: shown,
    builder: (context, show, _) => show
        ? Column(
            children: [
              Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    final actions = PluginStoreActions(context);
                    actions.install(
                      repoUrl: repoA,
                      slug: 'plain',
                      name: 'Plain',
                      repoName: 'Kho A',
                    );
                    actions.install(
                      repoUrl: repoA,
                      slug: 'plain',
                      name: 'Plain',
                      repoName: 'Kho A',
                    );
                  },
                  child: const Text('twice'),
                ),
              ),
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => PluginStoreActions(context).install(
                    repoUrl: repoA,
                    slug: 'plain',
                    name: 'Plain',
                    repoName: 'Kho A',
                  ),
                  child: const Text('once'),
                ),
              ),
            ],
          )
        : const SizedBox(),
  );
}

void main() {
  group('install guard', () {
    testWidgets('a second install of the same plugin does not start', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repos = FakeRepos()..installGate = gate;
      await pumpStore(
        tester,
        _Host(shown: ValueNotifier(true)),
        reposController: repos,
      );
      await tester.tap(find.text('twice'));
      await tester.pump();
      // A tap after the first one began is refused too.
      await tester.tap(find.text('once'));
      await tester.pump();
      expect(repos.installs, hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
      expect(repos.installs, hasLength(1));
      // Free again once the first finished.
      await tester.tap(find.text('once'));
      await tester.pumpAndSettle();
      expect(repos.installs, hasLength(2));
    });

    testWidgets('an unexpected error says something went wrong', (
      tester,
    ) async {
      final repos = FakeRepos()..installError = StateError('boom');
      await pumpStore(
        tester,
        _Host(shown: ValueNotifier(true)),
        reposController: repos,
      );
      await tester.tap(find.text('once'));
      await tester.pumpAndSettle();
      expect(find.text(en.lyricsStoreFailUnexpected), findsOneWidget);
      expect(find.text(en.lyricsStoreFailStorage), findsNothing);
      // The guard is released after the error.
      await tester.tap(find.text('once'));
      await tester.pumpAndSettle();
      expect(repos.installs, hasLength(2));
    });
  });

  group('screen closed meanwhile', () {
    testWidgets('a failure becomes a snackbar, with no dialog', (tester) async {
      final shown = ValueNotifier(true);
      final gate = Completer<void>();
      final repos = FakeRepos()
        ..installGate = gate
        ..installResult = const RepoPluginFailed(RepoPluginFailure.download);
      await pumpStore(tester, _Host(shown: shown), reposController: repos);
      await tester.tap(find.text('once'));
      await tester.pump();
      shown.value = false;
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(
          repoPluginFailureText(
            en,
            const RepoPluginFailed(RepoPluginFailure.download),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a mismatch becomes a snackbar without a retry', (
      tester,
    ) async {
      final shown = ValueNotifier(true);
      final gate = Completer<void>();
      final repos = FakeRepos()
        ..installGate = gate
        ..installResult = const RepoPluginFailed(
          RepoPluginFailure.catalogMismatch,
        );
      await pumpStore(tester, _Host(shown: shown), reposController: repos);
      await tester.tap(find.text('once'));
      await tester.pump();
      shown.value = false;
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(en.lyricsStoreFailMismatch), findsOneWidget);
      expect(repos.installs, hasLength(1));
    });

    testWidgets('needing a newer app becomes a snackbar', (tester) async {
      final shown = ValueNotifier(true);
      final gate = Completer<void>();
      final repos = FakeRepos()
        ..installGate = gate
        ..installResult = const RepoPluginFailed(
          RepoPluginFailure.needsNewerApp,
        );
      await pumpStore(tester, _Host(shown: shown), reposController: repos);
      await tester.tap(find.text('once'));
      await tester.pump();
      shown.value = false;
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(en.lyricsStoreNeedsNewerBody('Plain')), findsOneWidget);
    });

    testWidgets('a success still offers Undo', (tester) async {
      final shown = ValueNotifier(true);
      final gate = Completer<void>();
      final repos = FakeRepos()..installGate = gate;
      final plugins = FakePlugins();
      await pumpStore(
        tester,
        _Host(shown: shown),
        reposController: repos,
        plugins: plugins,
      );
      await tester.tap(find.text('once'));
      await tester.pump();
      shown.value = false;
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(plugins.undos, ['plugin-new']);
    });
  });

  group('mismatch retry reads the refreshed catalog', () {
    RepoPluginFailed mismatch(int declared) => RepoPluginFailed(
      RepoPluginFailure.catalogMismatch,
      packageDeclared: (version: declared, hosts: const ['music.example.com']),
    );

    testWidgets('the second dialog diffs against the new list', (tester) async {
      final repos = FakeRepos()..installResult = mismatch(2);
      repos.onRefresh = (_) {
        repos
          ..catalog = [_repoWith(5)]
          ..installResult = mismatch(4);
      };
      await pumpStore(
        tester,
        _page(),
        repos: [_repoWith(3)],
        reposController: repos,
      );
      await tester.tap(find.byTooltip('Install'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '•  The list says version 3, the downloaded package is version 2',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Refresh & try again'));
      await tester.pumpAndSettle();
      expect(repos.installs, hasLength(2));
      expect(
        find.text(
          '•  The list says version 5, the downloaded package is version 4',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('version 3'), findsNothing);
    });

    testWidgets('an entry that is gone after the refresh is said so', (
      tester,
    ) async {
      final repos = FakeRepos()..installResult = mismatch(2);
      repos.onRefresh = (_) => repos.catalog = [repoOf(repoA, 'Kho A')];
      await pumpStore(
        tester,
        _page(),
        repos: [_repoWith(3)],
        reposController: repos,
      );
      await tester.tap(find.byTooltip('Install'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh & try again'));
      await tester.pumpAndSettle();
      expect(repos.installs, hasLength(1));
      expect(find.text('•  ${en.lyricsStoreFailUnknownEntry}'), findsOneWidget);
    });

    testWidgets('the retry also clears the icon failures', (tester) async {
      final cache = _CountingIconCache();
      final repos = FakeRepos()..installResult = mismatch(2);
      await pumpStore(
        tester,
        _page(),
        repos: [_repoWith(3)],
        reposController: repos,
        overrides: [repoIconCacheProvider.overrideWithValue(cache)],
      );
      final before = cache.cleared;
      await tester.tap(find.byTooltip('Install'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh & try again'));
      await tester.pumpAndSettle();
      expect(cache.cleared, before + 1);
    });
  });

  group('update failures', () {
    Future<FakeRepos> pumpUpdate(
      WidgetTester tester,
      RepoPluginResult result, {
      void Function(FakeRepos)? configure,
    }) async {
      final repos = FakeRepos()..updateResult = result;
      configure?.call(repos);
      await pumpStore(
        tester,
        _page(),
        repos: [_repoWith(5)],
        records: [_installedPlain],
        reposController: repos,
      );
      await tester.tap(find.byTooltip('Update'));
      await tester.pumpAndSettle();
      return repos;
    }

    testWidgets('noNewerVersion is quiet', (tester) async {
      await pumpUpdate(
        tester,
        const RepoPluginFailed(RepoPluginFailure.noNewerVersion),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('needsNewerApp opens its own dialog', (tester) async {
      await pumpUpdate(
        tester,
        const RepoPluginFailed(RepoPluginFailure.needsNewerApp),
      );
      expect(find.text('Needs a newer Kanaru'), findsOneWidget);
    });

    testWidgets('a download failure opens the problem dialog', (tester) async {
      await pumpUpdate(
        tester,
        const RepoPluginFailed(RepoPluginFailure.download),
      );
      expect(find.text('Could not install'), findsOneWidget);
      expect(find.text('Plain · Repo: Kho A'), findsOneWidget);
    });

    testWidgets('a mismatch refreshes the repository and updates again', (
      tester,
    ) async {
      final repos = await pumpUpdate(
        tester,
        const RepoPluginFailed(
          RepoPluginFailure.catalogMismatch,
          packageDeclared: (version: 4, hosts: ['music.example.com']),
        ),
        configure: (r) => r.onRefresh = (_) => r.catalog = [_repoWith(6)],
      );
      expect(
        find.text(
          '•  The list says version 5, the downloaded package is version 4',
        ),
        findsOneWidget,
      );
      repos.updateResult = RepoPluginDone(
        recordOf('plugin-plain', version: 6),
        RepoPluginChange.updated,
      );
      await tester.tap(find.text('Refresh & try again'));
      await tester.pumpAndSettle();
      expect(repos.refreshed, [repoA]);
      expect(repos.updates, ['plugin-plain', 'plugin-plain']);
      expect(find.text('Updated Demo to v6'), findsOneWidget);
    });
  });

  group('update all', () {
    testWidgets('is off while it runs', (tester) async {
      final gate = Completer<void>();
      final repos = FakeRepos()..updateAllGate = gate;
      await pumpStore(
        tester,
        _page(),
        repos: [_repoWith(5)],
        records: [_installedPlain],
        reposController: repos,
      );
      TextButton button() =>
          tester.widget(find.widgetWithText(TextButton, 'Update all'));
      expect(button().onPressed, isNotNull);
      await tester.tap(find.text('Update all'));
      await tester.pump();
      expect(button().onPressed, isNull);
      await tester.tap(find.text('Update all'), warnIfMissed: false);
      await tester.pump();
      expect(repos.updateAllCalls, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(button().onPressed, isNotNull);
    });
  });

  group('results of the core', () {
    final installed = recordOf('plugin-file', name: 'FromZip');

    testWidgets('uninstall of a record that is gone does not say Uninstalled', (
      tester,
    ) async {
      final plugins = FakePlugins()
        ..uninstallResult = LyricsPluginUninstall.missing;
      await pumpStore(tester, _page(), records: [installed], plugins: plugins);
      await tester.tap(find.byTooltip('Uninstall plugin'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Uninstall'));
      await tester.pumpAndSettle();
      expect(find.text('Uninstalled FromZip'), findsNothing);
      expect(find.text(en.lyricsStoreAlreadyGone('FromZip')), findsOneWidget);
    });

    testWidgets('a plugin kept for its saved lyrics counts as uninstalled', (
      tester,
    ) async {
      final plugins = FakePlugins()
        ..uninstallResult = LyricsPluginUninstall.markedRemoved;
      await pumpStore(tester, _page(), records: [installed], plugins: plugins);
      await tester.tap(find.byTooltip('Uninstall plugin'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Uninstall'));
      await tester.pumpAndSettle();
      expect(find.text('Uninstalled FromZip'), findsOneWidget);
    });

    testWidgets('undo of a plugin that is already gone says so', (
      tester,
    ) async {
      final plugins = FakePlugins()
        ..undoResult = LyricsPluginUninstall.alreadyRemoved;
      await pumpStore(
        tester,
        _Host(shown: ValueNotifier(true)),
        plugins: plugins,
      );
      await tester.tap(find.text('once'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(plugins.undos, ['plugin-new']);
      expect(find.text(en.lyricsStoreAlreadyGone('Demo')), findsOneWidget);
    });

    testWidgets('the dialog names the author and version', (tester) async {
      await pumpStore(
        tester,
        _page(),
        records: [recordOf('plugin-a', name: 'Authored', author: 'hieu05')],
      );
      await tester.tap(find.byTooltip('Uninstall plugin'));
      await tester.pumpAndSettle();
      expect(find.text('hieu05 (self-declared) · v3'), findsOneWidget);
    });

    testWidgets('the dialog leaves the author out when there is none', (
      tester,
    ) async {
      await pumpStore(
        tester,
        _page(),
        records: [recordOf('plugin-a', name: 'Nameless')],
        locale: const Locale('vi'),
      );
      await tester.tap(find.byTooltip('Gỡ plugin'));
      await tester.pumpAndSettle();
      expect(find.text('v3'), findsOneWidget);
      expect(find.textContaining('tự khai'), findsNothing);
    });
  });

  group('updating spinners', () {
    test('start from the current set and miss no change', () async {
      final repos = FakeRepos()..setUpdating({'a'});
      final container = ProviderContainer(
        overrides: [
          lyricsPluginReposControllerProvider.overrideWithValue(repos),
        ],
      );
      addTearDown(container.dispose);
      final seen = <Set<String>>[];
      container.listen(
        pluginStoreUpdatingProvider,
        (_, next) => next.whenData(seen.add),
        fireImmediately: true,
      );
      // Changes right after the subscription must all arrive.
      repos
        ..setUpdating({'a', 'b'})
        ..setUpdating({});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(seen.first, {'a'});
      expect(seen.last, isEmpty);
      expect(container.read(pluginStoreUpdatingProvider).value, isEmpty);
    });
  });

  group('store rows follow the library', () {
    testWidgets('an install made on a store row moves it to Installed', (
      tester,
    ) async {
      await pumpStore(tester, _page(), repos: [_repoWith(3)]);
      expect(find.byTooltip('Install'), findsOneWidget);
      storeRecordsOf(tester).set([_installedPlain]);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Install'), findsNothing);
      expect(find.byTooltip('Uninstall plugin'), findsOneWidget);
    });
  });
}

/// Counts `clearFailures`; row icons are not asked for in these tests.
class _CountingIconCache extends Fake implements RepoIconCache {
  int cleared = 0;

  @override
  void clearFailures() => cleared++;

  // Rows ask for icons; none is available here.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #iconOf
      ? Future<Uint8List?>.value()
      : super.noSuchMethod(invocation);
}
