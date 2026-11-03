import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:material_ui/material_ui.dart';

import 'lyrics_sources_harness.dart';

PluginConfigField _input(
  PluginInputFormat format, {
  String key = 'k',
  String title = 'Field',
  bool required = false,
  int? minLength,
  num? min,
  num? max,
  num? step,
  int? rows,
  Object? defaultValue,
}) => PluginConfigField(
  key: key,
  title: title,
  mode: PluginConfigMode.input,
  inputFormat: format,
  required: required,
  minLength: minLength,
  min: min,
  max: max,
  step: step,
  rows: rows,
  defaultValue: defaultValue,
);

const _options = [
  PluginConfigOption(value: 'eu', title: 'Europe', subtitle: 'Fast there'),
  PluginConfigOption(value: 'us', title: 'America'),
  PluginConfigOption(value: 'as', title: 'Asia'),
];

void main() {
  Future<FakePlugins> open(
    WidgetTester tester,
    PluginConfigField field, {
    FakePlugins? plugins,
  }) async {
    final fake = plugins ?? FakePlugins();
    await pumpSources(
      tester,
      records: [
        testRecord(idA, name: 'Alpha', config: [field]),
      ],
      plugins: fake,
      location: lyricsPluginRoute(idA),
    );
    return fake;
  }

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

  group('text', () {
    testWidgets('a required empty field says so only after it was left', (
      tester,
    ) async {
      final plugins = await open(
        tester,
        _input(PluginInputFormat.text, title: 'Name', required: true),
      );
      expect(find.text(en.pluginConfigRequired), findsNothing);
      expect(box('Name *'), findsOneWidget);

      await tester.tap(box('Name *'));
      await tester.pump();
      expect(find.text(en.pluginConfigRequired), findsNothing);
      await blur(tester);
      expect(find.text(en.pluginConfigRequired), findsOneWidget);
      expect(plugins.configWrites, isEmpty);

      await type(tester, box('Name *'), 'x');
      expect(find.text(en.pluginConfigRequired), findsNothing);
    });

    testWidgets('a short text is refused inline and saved once fixed', (
      tester,
    ) async {
      final plugins = await open(
        tester,
        _input(PluginInputFormat.text, title: 'Name', minLength: 3),
      );
      await type(tester, box('Name'), 'ab');
      expect(find.text(en.pluginConfigTooShort(3)), findsNothing);
      await blur(tester);
      expect(find.text(en.pluginConfigTooShort(3)), findsOneWidget);
      expect(plugins.configWrites, isEmpty);

      await type(tester, box('Name'), 'abc');
      expect(find.text(en.pluginConfigTooShort(3)), findsNothing);
      await blur(tester);
      expect(plugins.configWrites, [(idA, 'k', 'abc')]);
    });

    testWidgets('a url must be https', (tester) async {
      final plugins = await open(
        tester,
        _input(PluginInputFormat.url, title: 'Site'),
      );
      await type(tester, box('Site'), 'http://example.com');
      await blur(tester);
      expect(find.text(en.pluginConfigUrlInvalid), findsOneWidget);
      expect(plugins.configWrites, isEmpty);

      await type(tester, box('Site'), 'https://example.com');
      await blur(tester);
      expect(plugins.configWrites, [(idA, 'k', 'https://example.com')]);
    });

    testWidgets('a multiline box keeps Enter for newlines and saves on blur', (
      tester,
    ) async {
      final plugins = await open(
        tester,
        _input(PluginInputFormat.multiline, title: 'Notes', rows: 4),
      );
      final field = tester.widget<TextField>(box('Notes'));
      expect(field.maxLines, 4);
      await type(tester, box('Notes'), 'a\nb');
      expect(plugins.configWrites, isEmpty);
      await blur(tester);
      expect(plugins.configWrites, [(idA, 'k', 'a\nb')]);
    });

    testWidgets('a refusal from the store shows inline, not in a snackbar', (
      tester,
    ) async {
      final plugins = await open(
        tester,
        _input(PluginInputFormat.text, title: 'Name'),
        plugins: FakePlugins()..configResult = PluginConfigWrite.invalidValue,
      );
      await type(tester, box('Name'), 'x');
      await blur(tester);
      expect(find.text(en.pluginConfigInvalidValue), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(plugins.configWrites, hasLength(1));
      // The same refused text is not sent again.
      await tester.tap(box('Name'));
      await blur(tester);
      expect(plugins.configWrites, hasLength(1));
      expect(find.text(en.pluginConfigInvalidValue), findsOneWidget);
    });
  });

  group('number and integer', () {
    testWidgets('a number saves as a number, a limit is refused inline', (
      tester,
    ) async {
      final plugins = await open(
        tester,
        _input(PluginInputFormat.number, title: 'Limit', max: 20),
      );
      await type(tester, box('Limit'), '99');
      await blur(tester);
      expect(find.text(en.pluginConfigAboveMax('20')), findsOneWidget);
      expect(plugins.configWrites, isEmpty);

      await type(tester, box('Limit'), '7.5');
      await blur(tester);
      expect(plugins.configWrites, [(idA, 'k', 7.5)]);
    });

    testWidgets('an integer saves as an int and refuses a broken one', (
      tester,
    ) async {
      final plugins = await open(
        tester,
        _input(PluginInputFormat.integer, title: 'Count'),
      );
      await type(tester, box('Count'), '1-');
      await blur(tester);
      expect(find.text(en.pluginConfigIntegerInvalid), findsOneWidget);

      await type(tester, box('Count'), '4');
      await blur(tester);
      final written = plugins.configWrites.single.$3;
      expect(written, 4);
      expect(written, isA<int>());
    });

    testWidgets('arrow keys step within min and max', (tester) async {
      final plugins = await open(
        tester,
        _input(
          PluginInputFormat.number,
          title: 'Level',
          min: 0,
          max: 3,
          step: 2,
          defaultValue: 2,
        ),
      );
      expect(tester.widget<TextField>(box('Level')).controller!.text, '2');
      await tester.tap(box('Level'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(tester.widget<TextField>(box('Level')).controller!.text, '3');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(tester.widget<TextField>(box('Level')).controller!.text, '0');
      await blur(tester);
      expect(plugins.configWrites, [(idA, 'k', 0)]);
    });
  });

  group('select', () {
    testWidgets('the dropdown lists the option subtitle', (tester) async {
      await open(
        tester,
        const PluginConfigField(
          key: 'k',
          title: 'Region',
          mode: PluginConfigMode.select,
          options: _options,
          defaultValue: 'us',
        ),
      );
      expect(find.text('Fast there'), findsNothing);
      await tester.tap(find.text('America'));
      await tester.pumpAndSettle();
      expect(find.text('Fast there'), findsOneWidget);
    });

    testWidgets('a refused choice flips back with an inline error', (
      tester,
    ) async {
      await open(
        tester,
        const PluginConfigField(
          key: 'k',
          title: 'Region',
          mode: PluginConfigMode.select,
          options: _options,
          defaultValue: 'us',
        ),
        plugins: FakePlugins()..configResult = PluginConfigWrite.invalidValue,
      );
      await tester.tap(find.text('America'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asia').last);
      await tester.pumpAndSettle();
      expect(find.text('America'), findsOneWidget);
      expect(find.text(en.pluginConfigInvalidValue), findsOneWidget);
    });

    testWidgets('chips save each toggle and respect the item limits', (
      tester,
    ) async {
      final plugins = await open(
        tester,
        const PluginConfigField(
          key: 'k',
          title: 'Regions',
          mode: PluginConfigMode.select,
          selectFormat: PluginSelectFormat.multiple,
          options: _options,
          minItems: 1,
          maxItems: 2,
        ),
      );
      await tester.tap(find.text('Europe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asia'));
      await tester.pumpAndSettle();
      expect(plugins.configWrites.map((w) => w.$3), [
        ['eu'],
        ['eu', 'as'],
      ]);

      await tester.tap(find.text('America'));
      await tester.pumpAndSettle();
      expect(find.text(en.pluginConfigTooManyItems(2)), findsOneWidget);
      expect(plugins.configWrites, hasLength(2));

      await tester.tap(find.text('America'));
      await tester.tap(find.text('Asia'));
      await tester.tap(find.text('Europe'));
      await tester.pumpAndSettle();
      expect(find.text(en.pluginConfigRequired), findsNothing);
      expect(find.text(en.pluginConfigTooFewItems(1)), findsOneWidget);
    });
  });

  group('list', () {
    const list = PluginConfigField(
      key: 'k',
      title: 'Hosts',
      mode: PluginConfigMode.list,
      maxItems: 2,
    );

    testWidgets('add, edit and remove save the whole list', (tester) async {
      final plugins = FakePlugins()
        ..stored = {
          'k': ['a'],
        };
      await open(tester, list, plugins: plugins);
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.text(en.pluginConfigAddItem));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'b');
      await blur(tester);
      expect(plugins.configWrites.last.$3, ['a', 'b']);
      // Add is off at the limit.
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, en.pluginConfigAddItem),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byTooltip(en.pluginConfigRemoveItem).first);
      await tester.pumpAndSettle();
      expect(plugins.configWrites.last.$3, ['b']);
    });

    testWidgets('empty rows are not saved and a bad item is refused', (
      tester,
    ) async {
      final plugins = await open(
        tester,
        const PluginConfigField(
          key: 'k',
          title: 'Sizes',
          mode: PluginConfigMode.list,
          listFormat: PluginListFormat.integer,
        ),
      );
      await tester.tap(find.text(en.pluginConfigAddItem));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.pluginConfigAddItem));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '1-');
      await blur(tester);
      expect(find.text(en.pluginConfigItemInvalid), findsOneWidget);
      expect(plugins.configWrites, isEmpty);

      await tester.enterText(find.byType(TextField).first, '3');
      await blur(tester);
      expect(plugins.configWrites.single.$3, [3]);
    });
  });

  group('map', () {
    const map = PluginConfigField(
      key: 'k',
      title: 'Headers',
      mode: PluginConfigMode.map,
    );

    testWidgets('a row is saved as a map entry', (tester) async {
      final plugins = await open(tester, map);
      await tester.tap(find.text(en.pluginConfigAddItem));
      await tester.pumpAndSettle();
      await tester.enterText(box(en.pluginConfigMapKeyLabel), 'x-id');
      await tester.enterText(box(en.pluginConfigMapValueLabel), '42');
      await blur(tester);
      // Leaving the name box saved the row once, leaving the value box again.
      expect(plugins.configWrites.last.$3, {'x-id': '42'});
    });

    testWidgets('a repeated name shows on its row and blocks the save', (
      tester,
    ) async {
      final plugins = FakePlugins()
        ..stored = {
          'k': {'a': '1'},
        };
      await open(tester, map, plugins: plugins);
      await tester.tap(find.text(en.pluginConfigAddItem));
      await tester.pumpAndSettle();
      await tester.enterText(box(en.pluginConfigMapKeyLabel).last, 'a');
      await blur(tester);
      expect(find.text(en.pluginConfigKeyDuplicate), findsOneWidget);
      expect(plugins.configWrites, isEmpty);

      await tester.enterText(box(en.pluginConfigMapKeyLabel).last, 'b');
      await blur(tester);
      expect(find.text(en.pluginConfigKeyDuplicate), findsNothing);
      expect(plugins.configWrites.single.$3, {'a': '1', 'b': ''});
    });
  });
}
