import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_problem.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:material_ui/material_ui.dart';

import '../lyrics_plugin_store/store_test_harness.dart' as store;
import 'lyrics_sources_harness.dart';

void main() {
  const id = 'plugin-from-repo';
  final repo = store.repoOf(
    store.repoA,
    'Kho A',
    entries: [store.entryOf('plain', name: 'Plain', version: 5)],
  );
  final installed = store.recordOf(
    id,
    name: 'Plain',
    version: 3,
    repoUrl: store.repoA,
    repoSlug: 'plain',
  );

  Future<store.FakeRepos> pump(
    WidgetTester tester, {
    store.FakeRepos? fakeRepos,
    required List<LyricsPluginRecord> records,
    bool controller = true,
    List<PluginRepo>? repos,
    Stream<List<PluginRepo>>? repoStream,
    Stream<LyricsSourcesInput>? input,
  }) async {
    final fake = fakeRepos ?? store.FakeRepos();
    await pumpSources(
      tester,
      records: records,
      plugins: FakePlugins(),
      location: lyricsPluginRoute(id),
      input: input,
      overrides: [
        lyricsPluginReposProvider.overrideWith(
          (ref) => repoStream ?? Stream.value(repos ?? [repo]),
        ),
        lyricsPluginReposControllerProvider.overrideWithValue(
          controller ? fake : null,
        ),
      ],
    );
    return fake;
  }

  testWidgets('a newer catalog version shows the banner', (tester) async {
    await pump(tester, records: [installed]);
    expect(find.text(en.pluginUpdateAvailable(5)), findsOneWidget);
    expect(find.text(en.pluginUpdateAction), findsOneWidget);
  });

  testWidgets('the banner is in Vietnamese too', (tester) async {
    await pumpSources(
      tester,
      records: [installed],
      plugins: FakePlugins(),
      location: lyricsPluginRoute(id),
      locale: const Locale('vi'),
      overrides: [
        lyricsPluginReposProvider.overrideWith((ref) => Stream.value([repo])),
        lyricsPluginReposControllerProvider.overrideWithValue(
          store.FakeRepos(),
        ),
      ],
    );
    expect(find.text('Có bản mới v5'), findsOneWidget);
    expect(find.text('Cập nhật'), findsOneWidget);
  });

  testWidgets('no banner for a plugin from a file', (tester) async {
    await pump(tester, records: [store.recordOf(id, name: 'Plain')]);
    expect(find.text(en.pluginUpdateAction), findsNothing);
  });

  testWidgets('no banner when the catalog version is not newer', (
    tester,
  ) async {
    await pump(
      tester,
      records: [installed],
      repos: [
        store.repoOf(
          store.repoA,
          'Kho A',
          entries: [store.entryOf('plain', version: 3)],
        ),
      ],
    );
    expect(find.text(en.pluginUpdateAction), findsNothing);
  });

  testWidgets('no banner when the repository was removed', (tester) async {
    await pump(tester, records: [installed], repos: const []);
    expect(find.text(en.pluginUpdateAction), findsNothing);
  });

  testWidgets('no banner without a repository controller', (tester) async {
    await pump(tester, records: [installed], controller: false);
    expect(find.text(en.pluginUpdateAction), findsNothing);
  });

  testWidgets('Update calls the controller and reports the new version', (
    tester,
  ) async {
    final fake = await pump(tester, records: [installed]);
    fake.updateResult = RepoPluginDone(
      store.recordOf(id, name: 'Plain', version: 5),
      RepoPluginChange.updated,
    );
    await tester.tap(find.text(en.pluginUpdateAction));
    await tester.pump();
    await tester.pump();
    expect(fake.updates, [id]);
    expect(find.text(en.lyricsStoreUpdated('Plain', 5)), findsOneWidget);
  });

  testWidgets('a refused package shows the title and the reason', (
    tester,
  ) async {
    final fake = await pump(tester, records: [installed]);
    fake.updateResult = const RepoPluginFailed(
      RepoPluginFailure.rejected,
      problem: PluginPackageProblem(PluginPackageProblemKind.notZip),
    );
    await tester.tap(find.text(en.pluginUpdateAction));
    await tester.pump();
    await tester.pump();
    expect(find.text(en.pluginUpdateFailed('Plain')), findsOneWidget);
    expect(find.text(en.pluginProblemNotZip), findsOneWidget);
  });

  Future<void> failWith(WidgetTester tester, RepoPluginFailed failed) async {
    final fake = await pump(tester, records: [installed]);
    fake.updateResult = failed;
    await tester.tap(find.text(en.pluginUpdateAction));
    await tester.pump();
    await tester.pump();
    expect(find.text(en.pluginUpdateFailed('Plain')), findsOneWidget);
  }

  testWidgets('a download failure shows the title and the network reason', (
    tester,
  ) async {
    await failWith(tester, const RepoPluginFailed(RepoPluginFailure.download));
    expect(
      find.text(en.lyricsStoreFailDownload(en.lyricsStoreLoadNetwork)),
      findsOneWidget,
    );
  });

  testWidgets('a catalog mismatch shows its reason', (tester) async {
    await failWith(
      tester,
      const RepoPluginFailed(RepoPluginFailure.catalogMismatch),
    );
    expect(find.text(en.lyricsStoreFailMismatch), findsOneWidget);
  });

  testWidgets('a storage failure shows its reason', (tester) async {
    await failWith(tester, const RepoPluginFailed(RepoPluginFailure.storage));
    expect(find.text(en.lyricsStoreFailStorage), findsOneWidget);
  });

  testWidgets('a thrown error shows the failure title', (tester) async {
    await pump(tester, records: [installed], fakeRepos: _Throwing());
    await tester.tap(find.text(en.pluginUpdateAction));
    await tester.pump();
    await tester.pump();
    expect(find.text(en.pluginUpdateFailed('Plain')), findsOneWidget);
    // The button is free again.
    expect(find.text(en.pluginUpdateAction), findsOneWidget);
  });

  testWidgets('the button waits while the update runs', (tester) async {
    final gate = Completer<RepoPluginResult>();
    final fake = _Gated(gate);
    await pump(tester, records: [installed], fakeRepos: fake);
    await tester.tap(find.text(en.pluginUpdateAction));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel(en.lyricsStoreWorking), findsOneWidget);
    expect(find.text(en.pluginUpdateAction), findsNothing);
    gate.complete(const RepoPluginFailed(RepoPluginFailure.noNewerVersion));
    await tester.pump();
    await tester.pump();
    expect(fake.updates, [id]);
    expect(find.text(en.lyricsStoreFailNoNewerVersion), findsOneWidget);
  });

  testWidgets('the button is disabled while the core updates this plugin', (
    tester,
  ) async {
    final fake = store.FakeRepos();
    await pump(tester, records: [installed], fakeRepos: fake);
    FilledButton button() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button().onPressed, isNotNull);
    fake.setUpdating({id});
    await tester.pump();
    await tester.pump();
    expect(button().onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Started elsewhere: no message from here.
    expect(find.byType(SnackBar), findsNothing);
    fake.setUpdating({});
    await tester.pump();
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });

  testWidgets('another plugin updating leaves the button enabled', (
    tester,
  ) async {
    final fake = store.FakeRepos()..setUpdating({'other'});
    await pump(tester, records: [installed], fakeRepos: fake);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('a second tap while updating does not update twice', (
    tester,
  ) async {
    final gate = Completer<RepoPluginResult>();
    final fake = _Gated(gate);
    await pump(tester, records: [installed], fakeRepos: fake);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(fake.updates, [id]);
    gate.complete(const RepoPluginFailed(RepoPluginFailure.noNewerVersion));
    await tester.pump();
    await tester.pump();
  });

  testWidgets('the banner goes once the new version is installed', (
    tester,
  ) async {
    final records = StreamController<LyricsSourcesInput>();
    final repos = StreamController<List<PluginRepo>>();
    addTearDown(records.close);
    addTearDown(repos.close);
    final fake = await pump(
      tester,
      records: [installed],
      input: records.stream,
      repoStream: repos.stream,
    );
    records.add(LyricsSourcesInput([installed], const []));
    repos.add([repo]);
    await tester.pumpAndSettle();
    expect(find.text(en.pluginUpdateAction), findsOneWidget);
    fake.updateResult = RepoPluginDone(
      store.recordOf(id, name: 'Plain', version: 5),
      RepoPluginChange.updated,
    );
    await tester.tap(find.text(en.pluginUpdateAction));
    await tester.pump();
    // The records stream carries the installed version.
    records.add(
      LyricsSourcesInput([
        store.recordOf(
          id,
          name: 'Plain',
          version: 5,
          repoUrl: store.repoA,
          repoSlug: 'plain',
        ),
      ], const []),
    );
    await tester.pumpAndSettle();
    expect(find.text(en.pluginUpdateAction), findsNothing);
    expect(find.text(en.pluginUpdateAvailable(5)), findsNothing);
  });
}

/// An update that throws.
class _Throwing extends store.FakeRepos {
  @override
  Future<RepoPluginResult> update(String installId) async =>
      throw StateError('boom');
}

/// An update that waits for the test.
class _Gated extends store.FakeRepos {
  _Gated(this._gate);

  final Completer<RepoPluginResult> _gate;

  @override
  Future<RepoPluginResult> update(String installId) {
    updates.add(installId);
    return _gate.future;
  }
}
