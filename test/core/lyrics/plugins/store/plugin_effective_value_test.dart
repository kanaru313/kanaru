import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/store/plugin_config_values.dart';

import 'store_test_env.dart';

const _options = [
  PluginConfigOption(value: 'eu', title: 'EU'),
  PluginConfigOption(value: 'us', title: 'US'),
];

PluginConfigField _field(
  PluginConfigMode mode, {
  PluginInputFormat? input,
  PluginSelectFormat? select,
  PluginListFormat? list,
  num? max,
  Object? defaultValue,
}) => PluginConfigField(
  key: 'k',
  title: 'K',
  mode: mode,
  inputFormat: input,
  selectFormat: select,
  listFormat: list,
  options: mode == PluginConfigMode.select ? _options : const [],
  max: max,
  defaultValue: defaultValue,
);

void main() {
  late StoreEnv env;

  setUp(() async => env = await StoreEnv.create());
  tearDown(() => env.dispose());

  // Each case: a field, and what is stored for it (absent when null).
  final cases = <String, (PluginConfigField, Object?)>{
    'toggle stored': (_field(PluginConfigMode.toggle), true),
    'toggle default': (
      _field(PluginConfigMode.toggle, defaultValue: false),
      null,
    ),
    'select stored': (
      _field(PluginConfigMode.select, select: PluginSelectFormat.single),
      'us',
    ),
    'select default': (
      _field(
        PluginConfigMode.select,
        select: PluginSelectFormat.single,
        defaultValue: 'eu',
      ),
      null,
    ),
    'select stored no longer an option': (
      _field(
        PluginConfigMode.select,
        select: PluginSelectFormat.single,
        defaultValue: 'eu',
      ),
      'gone',
    ),
    'multiple select': (
      _field(PluginConfigMode.select, select: PluginSelectFormat.multiple),
      ['eu', 'us'],
    ),
    'text': (
      _field(PluginConfigMode.input, input: PluginInputFormat.text),
      'x',
    ),
    'text of the wrong type': (
      _field(PluginConfigMode.input, input: PluginInputFormat.text),
      3,
    ),
    'number over its max': (
      _field(PluginConfigMode.input, input: PluginInputFormat.number, max: 5),
      9,
    ),
    'integer default': (
      _field(
        PluginConfigMode.input,
        input: PluginInputFormat.integer,
        defaultValue: 4,
      ),
      null,
    ),
    'list': (_field(PluginConfigMode.list), ['a', 'b']),
    'map': (_field(PluginConfigMode.map), {'a': 'b'}),
    'nothing': (_field(PluginConfigMode.map), null),
  };

  for (final entry in cases.entries) {
    test('matches configForRun: ${entry.key}', () async {
      final (field, stored) = entry.value;
      final record = await env.controller.installPackage(
        testPackage(config: [field]),
        testRepoSource,
      );
      await env.db.setLyricsPluginConfigValues(record.installId, {
        'k': ?stored,
      });
      final run = (await env.controller.configForRun(record.installId))['k'];
      final values = await env.controller.storedConfig(record.installId);
      expect(pluginEffectiveValue(field, values), run);
    });
  }

  group('pluginEffectiveField', () {
    const model = PluginConfigField(
      key: 'model',
      title: 'Model',
      mode: PluginConfigMode.select,
      selectFormat: PluginSelectFormat.single,
      custom: true,
      options: [PluginConfigOption(value: 'a', title: 'A')],
    );

    test('adds the user choices after the plugin options', () {
      final field = pluginEffectiveField(model, {
        'model.custom': [
          {'value': 'mine', 'subtitle': 'note'},
          {'value': 'a'},
          {'value': 'mine'},
          {'value': 3},
          'x',
        ],
      });
      expect(field.options.map((o) => o.value), ['a', 'mine']);
      expect(field.options.last.title, 'mine');
      expect(field.options.last.subtitle, 'note');
      expect(field.custom, isTrue);
    });

    test('lets a user model be the effective value', () {
      final stored = {
        'model': 'mine',
        'model.custom': [
          {'value': 'mine'},
        ],
      };
      expect(pluginEffectiveValue(model, stored), isNull);
      expect(
        pluginEffectiveValue(pluginEffectiveField(model, stored), stored),
        'mine',
      );
    });

    test('a field without custom is returned as is', () {
      final plain = model.withOptions(model.options);
      const notCustom = PluginConfigField(
        key: 'model',
        title: 'Model',
        mode: PluginConfigMode.select,
        options: [PluginConfigOption(value: 'a', title: 'A')],
      );
      expect(
        pluginEffectiveField(notCustom, {
          'model.custom': [
            {'value': 'z'},
          ],
        }),
        same(notCustom),
      );
      expect(plain.custom, isTrue);
    });
  });

  group('combinedInstruction', () {
    test('joins the non-empty parts with a newline', () {
      expect(combinedInstruction('A', 'B'), 'A\nB');
      expect(combinedInstruction('A', null), 'A');
      expect(combinedInstruction('A', ''), 'A');
      expect(combinedInstruction('', 'B'), 'B');
      expect(combinedInstruction('', null), '');
    });

    test('is held to the documented bound, counting code points', () {
      final long = '😀' * (aiInstructionMaxRunes + 5);
      expect(
        combinedInstruction(long, 'B').runes.length,
        aiInstructionMaxRunes,
      );
    });
  });
}
