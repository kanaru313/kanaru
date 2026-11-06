import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/shared/lyrics_source_routes.dart';
import 'package:material_ui/material_ui.dart';

import 'lyrics_sources_harness.dart';

PluginConfigField _model({List<String> options = const ['m1', 'm2']}) =>
    PluginConfigField(
      key: 'model',
      title: 'Model',
      mode: PluginConfigMode.select,
      required: true,
      custom: true,
      options: [
        for (final o in options) PluginConfigOption(value: o, title: o),
      ],
    );

class _Jobs extends TranslationJobs {
  final cleared = <String>[];

  @override
  void clearFailures(TranslationServiceId service) =>
      cleared.add(service.value);
}

class _ThrowingPlugins extends FakePlugins {
  @override
  Future<PluginConfigWrite> addCustomModel(
    String installId,
    String value, {
    String? subtitle,
  }) => throw StateError('database is gone');
}

void main() {
  late _Jobs jobs;
  setUp(() => jobs = _Jobs());

  Future<FakePlugins> open(
    WidgetTester tester, {
    Map<String, Object?> stored = const {},
    PluginConfigField? model,
    FakePlugins? fake,
  }) async {
    final plugins = (fake ?? FakePlugins())..stored = {...stored};
    await pumpSources(
      tester,
      records: [
        testRecord(idA, name: 'Alpha', config: [model ?? _model()]),
      ],
      plugins: plugins,
      location: lyricsPluginRoute(idA),
      overrides: [translationJobsProvider.overrideWith(() => jobs)],
    );
    return plugins;
  }

  Future<void> openList(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
  }

  const mine = {
    'model': 'mine',
    'model.custom': [
      {'value': 'mine', 'subtitle': 'Ollama at home'},
      {'value': 'other'},
    ],
  };

  testWidgets('the list ends with "Add model…" and tags the user\'s models', (
    tester,
  ) async {
    await open(tester, stored: mine);
    // The box shows the chosen one with its tag.
    expect(find.text('mine'), findsOneWidget);
    expect(find.text(en.pluginConfigCustomModelTag), findsOneWidget);

    await openList(tester);
    expect(find.text('m1'), findsOneWidget);
    expect(find.text('Ollama at home'), findsOneWidget);
    // One tag in the box, two in the list.
    expect(find.text(en.pluginConfigCustomModelTag), findsNWidgets(3));
    expect(find.byTooltip(en.pluginConfigRemoveCustomModel), findsNWidgets(2));
    expect(find.text(en.pluginConfigAddModel), findsOneWidget);
  });

  testWidgets('a field that is not custom has neither entry nor tag', (
    tester,
  ) async {
    await open(
      tester,
      model: const PluginConfigField(
        key: 'model',
        title: 'Model',
        mode: PluginConfigMode.select,
        options: [PluginConfigOption(value: 'm1', title: 'm1')],
      ),
    );
    await openList(tester);
    expect(find.text(en.pluginConfigAddModel), findsNothing);
    expect(find.byTooltip(en.pluginConfigRemoveCustomModel), findsNothing);
  });

  testWidgets('an empty list says there is no model yet', (tester) async {
    await open(tester, model: _model(options: const []));
    // The red "no model" state of a required field.
    expect(find.text(en.pluginConfigNoModel), findsOneWidget);
  });

  testWidgets('the dialog adds a model and selects it', (tester) async {
    final plugins = await open(tester);
    await openList(tester);
    await tester.tap(find.text(en.pluginConfigAddModel));
    await tester.pumpAndSettle();

    final add = find.widgetWithText(FilledButton, en.pluginConfigAddAndSelect);
    expect(tester.widget<FilledButton>(add).onPressed, isNull);
    await tester.enterText(
      find.widgetWithText(TextField, en.pluginConfigAddModelName),
      '  llama3  ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, en.pluginConfigAddModelNote),
      'at home',
    );
    await tester.pump();
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(plugins.customModelAdds, [(idA, 'llama3', 'at home')]);
    // The form rebuilt from the saved values: the new model is chosen.
    expect(find.text('llama3'), findsOneWidget);
    expect(find.text(en.pluginConfigCustomModelTag), findsOneWidget);
  });

  testWidgets('cancelling the dialog adds nothing', (tester) async {
    final plugins = await open(tester);
    await openList(tester);
    await tester.tap(find.text(en.pluginConfigAddModel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(plugins.customModelAdds, isEmpty);
  });

  testWidgets('a refused add shows the reason under the box', (tester) async {
    final plugins = await open(tester);
    plugins.configResult = PluginConfigWrite.invalidValue;
    await openList(tester);
    await tester.tap(find.text(en.pluginConfigAddModel));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, en.pluginConfigAddModelName),
      'x',
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, en.pluginConfigAddAndSelect),
    );
    await tester.pumpAndSettle();
    expect(find.text(en.pluginConfigInvalidValue), findsOneWidget);
  });

  testWidgets('removing a model that is not chosen rebuilds the list', (
    tester,
  ) async {
    final plugins = await open(tester, stored: mine);
    await openList(tester);
    // "other" is the second user entry.
    await tester.tap(find.byTooltip(en.pluginConfigRemoveCustomModel).last);
    await tester.pumpAndSettle();

    expect(plugins.customModelRemoves, [(idA, 'other')]);
    expect(find.text('mine'), findsOneWidget);
    await openList(tester);
    expect(find.byTooltip(en.pluginConfigRemoveCustomModel), findsOneWidget);
    expect(find.text('other'), findsNothing);
  });
  testWidgets('adding and removing a model make failed translations retry', (
    tester,
  ) async {
    final plugins = await open(tester, stored: mine);
    await openList(tester);
    await tester.tap(find.byTooltip(en.pluginConfigRemoveCustomModel).last);
    await tester.pumpAndSettle();
    expect(jobs.cleared, [idA]);

    await openList(tester);
    await tester.tap(find.text(en.pluginConfigAddModel));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, en.pluginConfigAddModelName),
      'fresh',
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, en.pluginConfigAddAndSelect),
    );
    await tester.pumpAndSettle();
    expect(plugins.customModelAdds, hasLength(1));
    expect(jobs.cleared, [idA, idA]);
  });

  testWidgets('a refused change does not forget failures', (tester) async {
    final plugins = await open(tester, stored: mine);
    plugins.configResult = PluginConfigWrite.invalidValue;
    await openList(tester);
    await tester.tap(find.byTooltip(en.pluginConfigRemoveCustomModel).last);
    await tester.pumpAndSettle();
    expect(jobs.cleared, isEmpty);
  });

  testWidgets('an error from the store shows the save failure', (tester) async {
    await open(tester, fake: _ThrowingPlugins());
    await openList(tester);
    await tester.tap(find.text(en.pluginConfigAddModel));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, en.pluginConfigAddModelName),
      'x',
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, en.pluginConfigAddAndSelect),
    );
    await tester.pumpAndSettle();
    expect(find.text(en.pluginConfigSaveFailed), findsOneWidget);
  });
}
