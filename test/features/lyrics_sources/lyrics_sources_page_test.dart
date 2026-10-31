import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_log_paths.dart';
import 'package:kanaru/features/lyrics_sources/lyrics_sources_menu.dart';
import 'package:kanaru/features/lyrics_sources/plugin_open_url.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';

import 'lyrics_sources_harness.dart';

void main() {
  final two = [
    testRecord(idA, name: 'Alpha', author: 'hieu05'),
    testRecord(
      idB,
      name: 'Beta',
      author: null,
      kind: LyricsPluginSourceKind.repo,
      sourceName: 'Repo B',
      installedAt: 2000,
    ),
  ];

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('lists LRCLIB first, then plugins with author and source', (
    tester,
  ) async {
    await pumpSources(tester, records: two, plugins: FakePlugins());

    expect(find.text(en.lyricsSourcesTitle), findsOneWidget);
    expect(top(tester, 'LRCLIB'), lessThan(top(tester, 'Alpha')));
    expect(top(tester, 'Alpha'), lessThan(top(tester, 'Beta')));
    expect(find.text(en.lyricsSourceBuiltIn), findsOneWidget);
    expect(
      find.text(en.lyricsSourceBuiltInHosts('lrclib.net')),
      findsOneWidget,
    );
    expect(
      find.text('hieu05 (self-declared) · v3 · File: demo.zip'),
      findsOneWidget,
    );
    expect(find.text('Unknown author · v3 · Repo: Repo B'), findsOneWidget);
    expect(find.text(en.lyricsSourcesEmptyHint), findsNothing);
  });

  testWidgets('shows the Vietnamese wording', (tester) async {
    await pumpSources(
      tester,
      records: two,
      plugins: FakePlugins(),
      locale: const Locale('vi'),
    );
    expect(find.text('Nguồn lời'), findsOneWidget);
    expect(find.text('Kho plugin'), findsOneWidget);
    expect(find.text('hieu05 (tự khai báo) · v3 · File: demo.zip'), findsOneWidget);
  });

  testWidgets('the Plugin store button is enabled', (tester) async {
    await pumpSources(tester, plugins: FakePlugins());

    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(en.lyricsSourcesStore),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('an empty plugin list shows LRCLIB and a hint', (tester) async {
    await pumpSources(tester, plugins: FakePlugins());
    expect(find.text('LRCLIB'), findsOneWidget);
    expect(find.text(en.lyricsSourcesEmptyHint), findsOneWidget);
  });

  testWidgets('a switch calls setEnabled', (tester) async {
    final plugins = FakePlugins();
    await pumpSources(tester, records: two, plugins: plugins);

    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();
    expect(plugins.enabled, [(idA, false)]);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(plugins.enabled.last, ('lrclib', false));
  });

  testWidgets('a disabled source shows its switch off', (tester) async {
    await pumpSources(
      tester,
      records: two,
      plugins: FakePlugins(),
      prefs: [
        const LyricsSourcePrefRow(providerId: idA, enabled: true, position: 1),
        const LyricsSourcePrefRow(providerId: idB, enabled: false, position: 2),
      ],
    );
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect([for (final s in switches) s.value], [true, true, false]);
  });

  testWidgets('dragging a handle calls reorder with the new id order', (
    tester,
  ) async {
    final plugins = FakePlugins();
    await pumpSources(tester, records: two, plugins: plugins);

    final handle = find.byIcon(AppIcons.dragHandle).at(1);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(plugins.reorders, [
      ['lrclib', idB, idA],
    ]);
  });

  testWidgets('Alt + arrow on a handle moves the row', (tester) async {
    final plugins = FakePlugins();
    await pumpSources(tester, records: two, plugins: plugins);

    // Focus the first handle (LRCLIB).
    Focus.of(tester.element(find.byIcon(AppIcons.dragHandle).first))
        .requestFocus();
    await tester.pump();
    await altKey(tester, LogicalKeyboardKey.arrowDown);
    expect(plugins.reorders, [
      [idA, 'lrclib', idB],
    ]);
  });

  testWidgets('a row offers move actions to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSources(tester, records: two, plugins: FakePlugins());

    final data = tester
        .getSemantics(find.byKey(const ValueKey(idA)))
        .getSemanticsData();
    expect(data.customSemanticsActionIds, isNotEmpty);
    handle.dispose();
  });

  testWidgets('a plugin row opens its page; LRCLIB has none', (tester) async {
    await pumpSources(tester, records: two, plugins: FakePlugins());

    await tester.tap(find.text('LRCLIB'));
    await tester.pumpAndSettle();
    // Still on the list: its store button shows and no plugin page opened.
    expect(find.text(en.lyricsSourcesStore), findsOneWidget);
    expect(find.byTooltip(en.pluginUninstall), findsNothing);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.byTooltip(en.pluginUninstall), findsOneWidget);
  });

  group('menu', () {
    testWidgets('opens the plugin log folder in the file manager', (
      tester,
    ) async {
      final shown = <String>[];
      final dir = Directory.systemTemp.createTempSync('plugin-logs-test');
      addTearDown(() => dir.deleteSync(recursive: true));
      await pumpSources(
        tester,
        plugins: FakePlugins(),
        overrides: [
          lyricsPluginLogDirProvider.overrideWithValue(
            Directory('${dir.path}/plugin-logs'),
          ),
          showInFileManagerProvider.overrideWithValue((path) async {
            shown.add(path);
            return true;
          }),
        ],
      );
      await tester.tap(find.byIcon(AppIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.lyricsSourcesMenuLogFolder));
      await tester.pumpAndSettle();
      expect(shown, ['${dir.path}/plugin-logs']);
    });

    testWidgets('opens the plugin guide on the repository', (tester) async {
      final opened = <String>[];
      await pumpSources(
        tester,
        plugins: FakePlugins(),
        overrides: [
          lyricsSourcesOpenUrlProvider.overrideWithValue((url) async {
            opened.add(url);
            return true;
          }),
        ],
      );
      await tester.tap(find.byIcon(AppIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.lyricsSourcesMenuGuide));
      await tester.pumpAndSettle();
      expect(opened, [lyricsPluginGuideUrl]);
      expect(lyricsPluginGuideUrl, endsWith('/docs/lyrics-plugin-api.md'));
    });

    testWidgets('says so when the guide cannot be opened', (tester) async {
      await pumpSources(
        tester,
        plugins: FakePlugins(),
        overrides: [
          lyricsSourcesOpenUrlProvider.overrideWithValue((url) async => false),
        ],
      );
      await tester.tap(find.byIcon(AppIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.lyricsSourcesMenuGuide));
      await tester.pumpAndSettle();
      expect(
        find.text(en.settingsOpenFailed(lyricsPluginGuideUrl)),
        findsOneWidget,
      );
    });
  });
}
