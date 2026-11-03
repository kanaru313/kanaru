import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';

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
  int? maxLength,
  num? max,
  int? maxItems,
  Object? defaultValue,
}) => PluginConfigField(
  key: 'k',
  title: 'K',
  mode: mode,
  inputFormat: input,
  selectFormat: select,
  listFormat: list,
  options: mode == PluginConfigMode.select ? _options : const [],
  maxLength: maxLength,
  max: max,
  maxItems: maxItems,
  defaultValue: defaultValue,
);

void main() {
  late StoreEnv env;

  setUp(() async => env = await StoreEnv.create());
  tearDown(() => env.dispose());

  // Stores [stored] behind the store's back, as an older version might have.
  Future<Object?> runWith(PluginConfigField field, Object stored) async {
    final record = await env.controller.installPackage(
      testPackage(config: [field]),
      testRepoSource,
    );
    await env.db.setLyricsPluginConfigValues(record.installId, {'k': stored});
    return (await env.controller.configForRun(record.installId))['k'];
  }

  final cases = <String, (PluginConfigField, Object)>{
    'text too long': (
      _field(
        PluginConfigMode.input,
        input: PluginInputFormat.text,
        maxLength: 3,
      ),
      'abcdef',
    ),
    'number out of range': (
      _field(PluginConfigMode.input, input: PluginInputFormat.number, max: 5),
      9,
    ),
    'select not an option': (_field(PluginConfigMode.select), 'moon'),
    'multi-select bad item': (
      _field(PluginConfigMode.select, select: PluginSelectFormat.multiple),
      ['eu', 'moon'],
    ),
    'toggle wrong type': (_field(PluginConfigMode.toggle), 'true'),
    'list bad item': (
      _field(PluginConfigMode.list, list: PluginListFormat.integer),
      [1, 'x'],
    ),
    'list too many items': (
      _field(PluginConfigMode.list, maxItems: 1),
      ['a', 'b'],
    ),
    'map bad key': (_field(PluginConfigMode.map), {' padded': 'v'}),
  };
  for (final entry in cases.entries) {
    test('unfit stored value is not run: ${entry.key}', () async {
      expect(await runWith(entry.value.$1, entry.value.$2), isNull);
    });
  }

  test('a number list is read typed', () async {
    final v = await runWith(
      _field(PluginConfigMode.list, list: PluginListFormat.number),
      [1, 2.5],
    );
    expect(v, [1, 2.5]);
  });

  test('changing a returned list or map changes nothing stored', () async {
    final list = _field(PluginConfigMode.list, defaultValue: ['a']);
    final record = await env.controller.installPackage(
      testPackage(config: [list]),
      testRepoSource,
    );
    final first = await env.controller.configForRun(record.installId);
    (first['k']! as List).add('b');
    final second = await env.controller.configForRun(record.installId);
    expect(second['k'], ['a']);
  });
}
