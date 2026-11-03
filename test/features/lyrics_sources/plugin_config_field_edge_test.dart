import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:material_ui/material_ui.dart';

import 'lyrics_sources_harness.dart';

/// Answers saves from a script, one entry per call (then `written`).
class _ScriptedPlugins extends FakePlugins {
  _ScriptedPlugins(this.script);

  final List<PluginConfigWrite> script;

  @override
  Future<PluginConfigWrite> setConfigValue(
    String installId,
    String key,
    Object? value,
  ) async {
    await super.setConfigValue(installId, key, value);
    return script.isEmpty ? PluginConfigWrite.written : script.removeAt(0);
  }
}

PluginConfigField _input(
  PluginInputFormat format, {
  num? min,
  num? max,
  num? step,
  Object? defaultValue,
}) => PluginConfigField(
  key: 'k',
  title: 'Field',
  mode: PluginConfigMode.input,
  inputFormat: format,
  min: min,
  max: max,
  step: step,
  defaultValue: defaultValue,
);

void main() {
  Future<void> open(
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

  Future<void> blur(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, Finder box, String text) async {
    await tester.tap(box);
    await tester.enterText(box, text);
    await tester.pump();
  }

  Finder box(String label) => find.widgetWithText(TextField, label);

  group('numbers that are not finite', () {
    testWidgets('a number field refuses 1e400 and still saves a good value', (
      tester,
    ) async {
      final plugins = FakePlugins();
      await open(tester, _input(PluginInputFormat.number), plugins);
      await type(tester, box('Field'), '1e400');
      await blur(tester);
      expect(find.text(en.pluginConfigNumberInvalid), findsOneWidget);
      expect(plugins.configWrites, isEmpty);
      expect(tester.takeException(), isNull);

      await type(tester, box('Field'), '5');
      await blur(tester);
      expect(plugins.configWrites, [(idA, 'k', 5)]);
    });

    testWidgets('a number list row refuses 1e400', (tester) async {
      final plugins = FakePlugins();
      await open(
        tester,
        const PluginConfigField(
          key: 'k',
          title: 'Field',
          mode: PluginConfigMode.list,
          listFormat: PluginListFormat.number,
        ),
        plugins,
      );
      await tester.tap(find.text(en.pluginConfigAddItem));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '1e400');
      await blur(tester);
      expect(find.text(en.pluginConfigItemInvalid), findsOneWidget);
      expect(plugins.configWrites, isEmpty);

      await tester.enterText(find.byType(TextField).first, '2');
      await blur(tester);
      expect(plugins.configWrites.single.$3, [2]);
    });

    testWidgets('the arrow keys never throw on a huge number', (tester) async {
      await open(tester, _input(PluginInputFormat.number), FakePlugins());
      await type(tester, box('Field'), '1e400');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('integer list rows take digits only', (tester) async {
    await open(
      tester,
      const PluginConfigField(
        key: 'k',
        title: 'Field',
        mode: PluginConfigMode.list,
        listFormat: PluginListFormat.integer,
      ),
      FakePlugins(),
    );
    await tester.tap(find.text(en.pluginConfigAddItem));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '0x1.5');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '015',
    );
  });

  testWidgets('a list row has a label naming it', (tester) async {
    await open(
      tester,
      const PluginConfigField(
        key: 'k',
        title: 'Field',
        mode: PluginConfigMode.list,
      ),
      FakePlugins()
        ..stored = {
          'k': ['a'],
        },
    );
    expect(find.bySemanticsLabel(RegExp('Field 1')), findsOneWidget);
  });

  testWidgets('a field closed while focused saves its edit without errors', (
    tester,
  ) async {
    final plugins = FakePlugins()
      ..stored = {
        'k': ['a'],
      };
    await open(
      tester,
      const PluginConfigField(
        key: 'k',
        title: 'Field',
        mode: PluginConfigMode.list,
      ),
      plugins,
    );
    await tester.enterText(find.byType(TextField).first, 'b');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(plugins.configWrites.map((w) => w.$3), [
      ['b'],
    ]);
  });

  testWidgets('a save in flight and the teardown save go in order', (
    tester,
  ) async {
    final gate = Completer<void>();
    final plugins = FakePlugins()..configGate = gate;
    await open(tester, _input(PluginInputFormat.text), plugins);
    await tester.enterText(box('Field'), 'a');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(box('Field'), 'b');
    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.pumpAndSettle();
    expect(plugins.configWrites.map((w) => w.$3), ['a', 'b']);
  });

  testWidgets('a failed earlier pick does not undo a newer one', (
    tester,
  ) async {
    final gate = Completer<void>();
    final plugins = _ScriptedPlugins([PluginConfigWrite.invalidValue])
      ..configGate = gate;
    await open(
      tester,
      const PluginConfigField(
        key: 'k',
        title: 'Region',
        mode: PluginConfigMode.select,
        options: [
          PluginConfigOption(value: 'eu', title: 'Europe'),
          PluginConfigOption(value: 'us', title: 'America'),
          PluginConfigOption(value: 'as', title: 'Asia'),
        ],
        defaultValue: 'us',
      ),
      plugins,
    );
    await tester.tap(find.text('America'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asia').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Europe').last);
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    expect(plugins.configWrites.map((w) => w.$3), ['as', 'eu']);
    expect(find.text('Europe'), findsOneWidget);
    expect(find.text(en.pluginConfigInvalidValue), findsNothing);
  });

  testWidgets('a keyring refusal can be tried again with the same value', (
    tester,
  ) async {
    final plugins = _ScriptedPlugins([PluginConfigWrite.secretStoreFailed]);
    await open(tester, _input(PluginInputFormat.text), plugins);
    await type(tester, box('Field'), 'x');
    await blur(tester);
    expect(find.text(en.pluginConfigSecretStoreFailed), findsOneWidget);

    await tester.tap(box('Field'));
    await blur(tester);
    expect(plugins.configWrites, hasLength(2));
    expect(find.text(en.pluginConfigSecretStoreFailed), findsNothing);
  });

  testWidgets('an integer step stays inside fractional limits', (tester) async {
    await open(
      tester,
      _input(PluginInputFormat.integer, max: 2.5, step: 1, defaultValue: 2),
      FakePlugins(),
    );
    await tester.tap(box('Field'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(tester.widget<TextField>(box('Field')).controller!.text, '2');
  });
}
