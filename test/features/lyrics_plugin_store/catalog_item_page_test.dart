import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Locale, Widget;
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import 'package:kanaru/features/lyrics_plugin_store/catalog_item_page.dart';

import 'store_test_harness.dart';

class _Opened {
  final ids = <String>[];

  Widget page({String slug = 'plain'}) =>
      CatalogItemPage(repoUrl: repoA, slug: slug, onOpenInstalled: ids.add);
}

void main() {
  final repo = repoOf(
    repoA,
    'Kho A',
    entries: [
      entryOf(
        'plain',
        name: 'Plain',
        version: 7,
        author: 'hieu05',
        description: 'Lyrics from somewhere',
        hosts: ['one.example.com', 'two.example.com'],
      ),
    ],
  );

  testWidgets('shows the details of the catalog entry', (tester) async {
    await pumpStore(tester, _Opened().page(), repos: [repo]);
    expect(find.text('Plain'), findsWidgets);
    expect(find.text('hieu05 (self-declared) · v7'), findsOneWidget);
    expect(find.text('Lyrics from somewhere'), findsOneWidget);
    expect(find.text('Kho A'), findsOneWidget);
    expect(find.text(repoA), findsOneWidget);
    expect(find.text('Can only connect to'), findsOneWidget);
    expect(find.text('one.example.com'), findsOneWidget);
    expect(find.text('two.example.com'), findsOneWidget);
  });

  testWidgets('Vietnamese marks the author as self-declared', (tester) async {
    await pumpStore(
      tester,
      _Opened().page(),
      repos: [repo],
      locale: const Locale('vi'),
    );
    expect(find.text('hieu05 (tự khai) · v7'), findsOneWidget);
    expect(find.text('Chỉ được kết nối tới'), findsOneWidget);
  });

  testWidgets('Cài installs through the same flow with Undo', (tester) async {
    final fake = FakeRepos();
    final plugins = FakePlugins();
    await pumpStore(
      tester,
      _Opened().page(),
      repos: [repo],
      reposController: fake,
      plugins: plugins,
    );
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    expect(fake.installs, [(repoA, 'plain')]);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(plugins.undos, ['plugin-new']);
  });

  testWidgets('an install failure opens the problem dialog', (tester) async {
    final fake = FakeRepos()
      ..installResult = const RepoPluginFailed(RepoPluginFailure.download);
    await pumpStore(
      tester,
      _Opened().page(),
      repos: [repo],
      reposController: fake,
    );
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    expect(find.text('Could not install'), findsOneWidget);
  });

  testWidgets('an installed plugin hands over to the installed page', (
    tester,
  ) async {
    final opened = _Opened();
    await pumpStore(
      tester,
      opened.page(),
      repos: [repo],
      records: [recordOf('plugin-plain', repoUrl: repoA, repoSlug: 'plain')],
    );
    expect(opened.ids, ['plugin-plain']);
    expect(find.text('Install'), findsNothing);
  });

  testWidgets('an unknown item says it is not in the repository', (
    tester,
  ) async {
    final opened = _Opened();
    await pumpStore(tester, opened.page(slug: 'nope'), repos: [repo]);
    expect(find.text('This plugin is not in the repository.'), findsOneWidget);
    expect(opened.ids, isEmpty);
  });
}
