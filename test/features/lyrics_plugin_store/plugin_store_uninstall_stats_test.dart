import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_data_stats_provider.dart';
import 'package:kanaru/features/lyrics_plugin_store/plugin_store_page.dart';
import 'package:material_ui/material_ui.dart';

import 'store_test_harness.dart';

Widget _page() => PluginStorePage(
  onOpenInstalled: (_) {},
  onOpenCatalogItem: (_, _) {},
  onOpenRepositories: () {},
);

final _installed = recordOf('plugin-file', name: 'FromZip');

void main() {
  testWidgets(
    'the dialog lists the same lines and numbers as the plugin page',
    (tester) async {
      await pumpStore(
        tester,
        _page(),
        records: [_installed],
        overrides: [
          pluginDataStatsProvider.overrideWith(
            (ref, id) async =>
                (storageBytes: 3200, foundCount: 57, textBytes: 215040),
          ),
        ],
      );
      await tester.tap(find.byTooltip(en.lyricsStoreUninstallTooltip));
      await tester.pumpAndSettle();

      expect(find.text(en.pluginUninstallTitle('FromZip')), findsOneWidget);
      expect(find.text(en.pluginUninstallRemoves), findsOneWidget);
      expect(find.text(en.pluginUninstallKeeps), findsOneWidget);
      expect(
        find.textContaining(en.pluginUninstallStorage('3 KB')),
        findsOneWidget,
      );
      expect(
        find.textContaining(en.pluginUninstallKeepLyrics(57)),
        findsOneWidget,
      );
      expect(find.textContaining(en.pluginUninstallKeepLrc), findsOneWidget);
    },
  );

  testWidgets('lyrics saved after the store opened are counted', (
    tester,
  ) async {
    var saved = 1;
    await pumpStore(
      tester,
      _page(),
      records: [_installed],
      overrides: [
        pluginDataStatsProvider.overrideWith(
          (ref, id) async =>
              (storageBytes: 0, foundCount: saved, textBytes: 10),
        ),
      ],
    );
    // A listener keeps the value cached, as an open plugin page would.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PluginStorePage)),
    );
    final sub = container.listen(
      pluginDataStatsProvider('plugin-file'),
      (_, _) {},
    );
    addTearDown(sub.close);
    await container.read(pluginDataStatsProvider('plugin-file').future);
    await tester.tap(find.byTooltip(en.lyricsStoreUninstallTooltip));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(en.pluginUninstallKeepLyrics(1)),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    saved = 4;
    await tester.tap(find.byTooltip(en.lyricsStoreUninstallTooltip));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(en.pluginUninstallKeepLyrics(4)),
      findsOneWidget,
    );
  });

  testWidgets('two quick taps open one dialog', (tester) async {
    final gate = Completer<PluginDataStats>();
    await pumpStore(
      tester,
      _page(),
      records: [_installed],
      overrides: [
        pluginDataStatsProvider.overrideWith((ref, id) => gate.future),
      ],
    );
    final button = find.byTooltip(en.lyricsStoreUninstallTooltip);
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    gate.complete((storageBytes: 0, foundCount: 0, textBytes: 0));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a failed stats read shows zeros and the dialog still opens', (
    tester,
  ) async {
    final plugins = FakePlugins();
    await pumpStore(
      tester,
      _page(),
      records: [_installed],
      plugins: plugins,
      overrides: [
        pluginDataStatsProvider.overrideWith(
          (ref, id) async => throw StateError('db closed'),
        ),
      ],
    );
    await tester.tap(find.byTooltip(en.lyricsStoreUninstallTooltip));
    await tester.pumpAndSettle();

    expect(find.text(en.pluginUninstallTitle('FromZip')), findsOneWidget);
    expect(
      find.textContaining(en.pluginUninstallStorage('0 B')),
      findsOneWidget,
    );
    expect(find.textContaining(en.pluginUninstallKeepPinned), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Uninstall'));
    await tester.pumpAndSettle();
    expect(plugins.uninstalls, ['plugin-file']);
  });

  testWidgets('closing the store during the stats read opens no dialog', (
    tester,
  ) async {
    final gate = Completer<PluginDataStats>();
    await pumpStore(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => Scaffold(body: _page())),
          ),
          child: const Text('open store'),
        ),
      ),
      records: [_installed],
      overrides: [
        pluginDataStatsProvider.overrideWith((ref, id) => gate.future),
      ],
    );
    await tester.tap(find.text('open store'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(en.lyricsStoreUninstallTooltip));
    await tester.pump();

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    gate.complete((storageBytes: 1, foundCount: 1, textBytes: 1));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
