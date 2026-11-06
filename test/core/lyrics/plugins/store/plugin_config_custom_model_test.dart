import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_config_values.dart';

import 'store_test_env.dart';

PluginConfigField _model({
  bool custom = true,
  List<String> options = const ['m1', 'm2'],
  bool required = true,
}) => PluginConfigField(
  key: 'model',
  title: 'Model',
  mode: PluginConfigMode.select,
  required: required,
  custom: custom,
  options: [for (final o in options) PluginConfigOption(value: o, title: o)],
);

void main() {
  late StoreEnv env;
  late LyricsPluginsController controller;
  final needsConfig = <String>[];

  Future<LyricsPluginRecord> install(
    PluginConfigField model, {
    PluginKind kind = PluginKind.lyrics,
  }) => controller.installPackage(
    testPackage(kind: kind, config: [model]),
    testRepoSource,
  );

  Future<Map<String, Object?>> stored(String id) => controller.storedConfig(id);

  setUp(() async {
    env = await StoreEnv.create();
    needsConfig.clear();
    controller = env.newController(
      onNeedsConfig: (id, name, kind) => needsConfig.add(id),
    );
  });
  tearDown(() => env.dispose());

  test('adding a model selects it and keeps the list, in one write', () async {
    final p = await install(_model());
    expect(
      await controller.addCustomModel(
        p.installId,
        '  gpt-x  ',
        subtitle: 'my server',
      ),
      PluginConfigWrite.written,
    );
    expect(await stored(p.installId), {
      'model': 'gpt-x',
      'model.custom': [
        {'value': 'gpt-x', 'subtitle': 'my server'},
      ],
    });
  });

  test('a name already a choice is only selected', () async {
    final p = await install(_model());
    await controller.addCustomModel(p.installId, 'mine');
    await controller.addCustomModel(p.installId, 'm2');
    expect((await stored(p.installId))['model'], 'm2');
    await controller.addCustomModel(p.installId, 'mine');
    final values = await stored(p.installId);
    expect(values['model'], 'mine');
    expect(values['model.custom'], [
      {'value': 'mine'},
    ]);
  });

  test('an empty, control-only or too long name or note is refused', () async {
    final p = await install(_model());
    for (final name in ['', '   ', '\n\t', 'x' * 201]) {
      expect(
        await controller.addCustomModel(p.installId, name),
        PluginConfigWrite.invalidValue,
        reason: name.length > 10 ? 'long' : 'blank',
      );
    }
    expect(
      await controller.addCustomModel(p.installId, 'ok', subtitle: 'y' * 301),
      PluginConfigWrite.invalidValue,
    );
    expect(await stored(p.installId), isEmpty);
  });

  test('the list is capped with the plugin options counted in', () async {
    final p = await install(_model(options: ['m1', 'm2']));
    for (var i = 0; i < pluginConfigMaxItems - 2; i++) {
      expect(
        await controller.addCustomModel(p.installId, 'c$i'),
        PluginConfigWrite.written,
      );
    }
    expect(
      await controller.addCustomModel(p.installId, 'one-too-many'),
      PluginConfigWrite.invalidValue,
    );
    final values = await stored(p.installId);
    expect(values['model'], 'c${pluginConfigMaxItems - 3}');
    expect((values['model.custom'] as List).length, pluginConfigMaxItems - 2);
    // Every saved model is still a choice: none vanished.
    final field = pluginEffectiveField(_model(options: ['m1', 'm2']), values);
    expect(field.options.length, pluginConfigMaxItems);
  });

  test('removing a model that is not selected keeps the selection', () async {
    final p = await install(_model());
    await controller.addCustomModel(p.installId, 'a');
    await controller.addCustomModel(p.installId, 'b');
    expect(
      await controller.removeCustomModel(p.installId, 'a'),
      PluginConfigWrite.written,
    );
    final values = await stored(p.installId);
    expect(values['model'], 'b');
    expect(values['model.custom'], [
      {'value': 'b'},
    ]);
  });

  test('removing the selected model selects the first choice', () async {
    final p = await install(_model());
    await controller.addCustomModel(p.installId, 'a');
    await controller.removeCustomModel(p.installId, 'a');
    final values = await stored(p.installId);
    expect(values['model'], 'm1');
    expect(values.containsKey('model.custom'), isFalse);
  });

  test('a value that is not one of the user\'s models is refused', () async {
    final p = await install(_model());
    expect(
      await controller.removeCustomModel(p.installId, 'm1'),
      PluginConfigWrite.invalidValue,
    );
    expect(
      await controller.removeCustomModel(p.installId, 'nope'),
      PluginConfigWrite.invalidValue,
    );
  });

  test('removing the last model of an empty list clears the model and '
      'reports the plugin', () async {
    final p = await install(_model(options: const []));
    await controller.addCustomModel(p.installId, 'only');
    await controller.setEnabled(p.installId, true);
    needsConfig.clear();
    expect(await controller.needsConfig(p.installId), isFalse);
    await controller.removeCustomModel(p.installId, 'only');
    expect(await stored(p.installId), isEmpty);
    expect(await controller.needsConfig(p.installId), isTrue);
    for (var i = 0; i < 20 && needsConfig.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(needsConfig, [p.installId]);
  });

  test('a field that is not custom has no list to add to', () async {
    final p = await install(_model(custom: false));
    expect(
      await controller.addCustomModel(p.installId, 'x'),
      PluginConfigWrite.unknownKey,
    );
    expect(
      await controller.removeCustomModel(p.installId, 'x'),
      PluginConfigWrite.unknownKey,
    );
  });

  test(
    'setValue takes a model the user added and refuses an unknown one',
    () async {
      final p = await install(_model());
      await controller.addCustomModel(p.installId, 'mine');
      await controller.setConfigValue(p.installId, 'model', 'm1');
      expect(
        await controller.setConfigValue(p.installId, 'model', 'mine'),
        PluginConfigWrite.written,
      );
      expect(
        await controller.setConfigValue(p.installId, 'model', 'stranger'),
        PluginConfigWrite.invalidValue,
      );
      // The list is the app's: a script-facing write cannot reach it.
      expect(
        await controller.setConfigValue(p.installId, 'model.custom', []),
        PluginConfigWrite.unknownKey,
      );
    },
  );

  test(
    'configForRun gives a script the model string and never the list',
    () async {
      final p = await install(_model(), kind: PluginKind.aiTranslate);
      await controller.addCustomModel(p.installId, 'my/model:7b');
      final config = await controller.configForRun(p.installId);
      expect(config, {'model': 'my/model:7b'});
      expect(config.containsKey('model.custom'), isFalse);
    },
  );

  test('an update that keeps custom keeps the list and the choice', () async {
    final p = await install(_model());
    await controller.addCustomModel(p.installId, 'mine');
    await controller.updatePackage(
      p.installId,
      testPackage(
        config: [
          _model(options: ['m1', 'm3']),
        ],
        version: 2,
      ),
    );
    final values = await stored(p.installId);
    expect(values['model'], 'mine');
    expect(values['model.custom'], [
      {'value': 'mine'},
    ]);
    expect((await controller.configForRun(p.installId))['model'], 'mine');
  });

  test('an update that drops custom drops the list and the model', () async {
    final p = await install(_model());
    await controller.addCustomModel(p.installId, 'mine');
    await controller.updatePackage(
      p.installId,
      testPackage(config: [_model(custom: false)], version: 2),
    );
    expect(await stored(p.installId), isEmpty);
  });

  test(
    'an update that drops custom keeps a model the plugin declares',
    () async {
      final p = await install(_model());
      await controller.addCustomModel(p.installId, 'mine');
      await controller.setConfigValue(p.installId, 'model', 'm2');
      await controller.updatePackage(
        p.installId,
        testPackage(config: [_model(custom: false)], version: 2),
      );
      expect(await stored(p.installId), {'model': 'm2'});
    },
  );
}
