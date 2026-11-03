import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:material_ui/material_ui.dart';

import 'lyrics_sources_harness.dart';

const _options = [
  PluginConfigOption(value: 'eu', title: 'Europe'),
  PluginConfigOption(value: 'us', title: 'America'),
  PluginConfigOption(value: 'as', title: 'Asia'),
];

const _toggle = PluginConfigField(
  key: 'k',
  title: 'Switch',
  mode: PluginConfigMode.toggle,
);
const _select = PluginConfigField(
  key: 'k',
  title: 'Region',
  mode: PluginConfigMode.select,
  options: _options,
  defaultValue: 'us',
);
const _multi = PluginConfigField(
  key: 'k',
  title: 'Regions',
  mode: PluginConfigMode.select,
  selectFormat: PluginSelectFormat.multiple,
  options: _options,
  defaultValue: ['eu'],
);

void main() {
  Future<GoRouter> open(
    WidgetTester tester,
    PluginConfigField field,
    FakePlugins plugins,
  ) => pumpSources(
    tester,
    records: [
      testRecord(idA, name: 'Alpha', config: [field]),
    ],
    plugins: plugins,
    location: lyricsPluginRoute(idA),
  );

  bool switchValue(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Switch'))
      .value;

  bool chipSelected(WidgetTester tester, String label) => tester
      .widget<FilterChip>(find.widgetWithText(FilterChip, label))
      .selected;

  group('a refused save goes back to the last saved value', () {
    testWidgets('toggle', (tester) async {
      final plugins = FakePlugins()..configResult = PluginConfigWrite.tooLarge;
      await open(tester, _toggle, plugins);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Switch'));
      await tester.pumpAndSettle();
      expect(switchValue(tester), isFalse);
      expect(find.text(en.pluginConfigTooLarge), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      // The same pick can be tried again.
      await tester.tap(find.widgetWithText(SwitchListTile, 'Switch'));
      await tester.pumpAndSettle();
      expect(plugins.configWrites, hasLength(2));
    });

    testWidgets('select', (tester) async {
      final plugins = FakePlugins()..configResult = PluginConfigWrite.tooLarge;
      await open(tester, _select, plugins);
      await tester.tap(find.text('America'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asia').last);
      await tester.pumpAndSettle();
      expect(find.text('America'), findsOneWidget);
      expect(find.text('Asia'), findsNothing);
      expect(find.text(en.pluginConfigTooLarge), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('multi-select', (tester) async {
      final plugins = FakePlugins()..configResult = PluginConfigWrite.tooLarge;
      await open(tester, _multi, plugins);
      await tester.tap(find.text('Asia'));
      await tester.pumpAndSettle();
      expect(chipSelected(tester, 'Asia'), isFalse);
      expect(chipSelected(tester, 'Europe'), isTrue);
      expect(find.text(en.pluginConfigTooLarge), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('quick successive picks', () {
    testWidgets('toggle: the last position is saved', (tester) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      await open(tester, _toggle, plugins);
      final tile = find.widgetWithText(SwitchListTile, 'Switch');
      await tester.tap(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();
      plugins.configGate!.complete();
      await tester.pumpAndSettle();
      expect(plugins.configWrites.map((w) => w.$3), [true, false]);
      expect(switchValue(tester), isFalse);
    });

    testWidgets('select: the last pick is saved after the one in flight', (
      tester,
    ) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      await open(tester, _select, plugins);
      await tester.tap(find.text('America'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Europe').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Europe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asia').last);
      await tester.pumpAndSettle();
      plugins.configGate!.complete();
      await tester.pumpAndSettle();
      expect(plugins.configWrites.map((w) => w.$3), ['eu', 'as']);
      expect(find.text('Asia'), findsOneWidget);
    });

    testWidgets('multi-select: the last choice is saved', (tester) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      await open(tester, _multi, plugins);
      await tester.tap(find.text('Asia'));
      await tester.pump();
      await tester.tap(find.text('America'));
      await tester.pump();
      plugins.configGate!.complete();
      await tester.pumpAndSettle();
      expect(plugins.configWrites.last.$3, ['eu', 'us', 'as']);
      expect(chipSelected(tester, 'America'), isTrue);
    });
  });

  group('closing the page mid-save still saves the last choice', () {
    Future<void> close(WidgetTester tester, GoRouter router) async {
      router.go(lyricsSourcesRoute);
      await tester.pump();
    }

    testWidgets('toggle', (tester) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      final router = await open(tester, _toggle, plugins);
      final tile = find.widgetWithText(SwitchListTile, 'Switch');
      await tester.tap(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();
      await close(tester, router);
      plugins.configGate!.complete();
      await tester.pumpAndSettle();
      expect(plugins.configWrites.map((w) => w.$3), [true, false]);
    });

    testWidgets('select', (tester) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      final router = await open(tester, _select, plugins);
      await tester.tap(find.text('America'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Europe').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Europe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asia').last);
      await tester.pumpAndSettle();
      await close(tester, router);
      plugins.configGate!.complete();
      await tester.pumpAndSettle();
      expect(plugins.configWrites.last.$3, 'as');
    });

    testWidgets('multi-select', (tester) async {
      final plugins = FakePlugins()..configGate = Completer<void>();
      final router = await open(tester, _multi, plugins);
      await tester.tap(find.text('Asia'));
      await tester.pump();
      await tester.tap(find.text('America'));
      await tester.pump();
      await close(tester, router);
      plugins.configGate!.complete();
      await tester.pumpAndSettle();
      expect(plugins.configWrites.last.$3, ['eu', 'us', 'as']);
    });
  });
}
