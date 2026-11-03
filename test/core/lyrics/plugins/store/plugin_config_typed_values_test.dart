import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';

import 'store_test_env.dart';

const _list = PluginConfigField(
  key: 'hosts',
  title: 'Hosts',
  mode: PluginConfigMode.list,
  maxItems: 3,
);
const _map = PluginConfigField(
  key: 'headers',
  title: 'Headers',
  mode: PluginConfigMode.map,
);
const _multi = PluginConfigField(
  key: 'regions',
  title: 'Regions',
  mode: PluginConfigMode.select,
  selectFormat: PluginSelectFormat.multiple,
  options: [
    PluginConfigOption(value: 'eu', title: 'EU'),
    PluginConfigOption(value: 'us', title: 'US'),
  ],
);
const _number = PluginConfigField(
  key: 'limit',
  title: 'Limit',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.number,
);

PluginConfigField _text(PluginInputFormat f, {int? maxLength}) =>
    PluginConfigField(
      key: 'k',
      title: 'K',
      mode: PluginConfigMode.input,
      inputFormat: f,
      maxLength: maxLength,
    );

void main() {
  late StoreEnv env;
  late LyricsPluginsController c;

  setUp(() async {
    env = await StoreEnv.create();
    c = env.controller;
  });
  tearDown(() => env.dispose());

  Future<String> install(List<PluginConfigField> f) async =>
      (await c.installPackage(
        testPackage(config: f),
        testRepoSource,
      )).installId;

  Future<void> update(String id, List<PluginConfigField> f) =>
      c.updatePackage(id, testPackage(version: 2, config: f));

  test('lists, maps and multi-selects are written and read typed', () async {
    final id = await install([_list, _map, _multi, _number]);
    expect(
      await c.setConfigValue(id, 'hosts', ['a', 'b']),
      PluginConfigWrite.written,
    );
    expect(
      await c.setConfigValue(id, 'headers', {'x': 'y'}),
      PluginConfigWrite.written,
    );
    expect(
      await c.setConfigValue(id, 'regions', ['eu']),
      PluginConfigWrite.written,
    );
    expect(await c.setConfigValue(id, 'limit', 2.5), PluginConfigWrite.written);
    expect(await c.configForRun(id), {
      'hosts': ['a', 'b'],
      'headers': {'x': 'y'},
      'regions': ['eu'],
      'limit': 2.5,
    });
  });

  test('an empty list is a stored value; null clears it', () async {
    final id = await install([_list]);
    await c.setConfigValue(id, 'hosts', <String>[]);
    expect((await c.configForRun(id))['hosts'], <Object>[]);
    await c.setConfigValue(id, 'hosts', null);
    expect(await c.configForRun(id), isEmpty);
  });

  test('wrong types and too many items are refused', () async {
    final id = await install([_list, _multi]);
    expect(
      await c.setConfigValue(id, 'hosts', 'a'),
      PluginConfigWrite.invalidValue,
    );
    expect(
      await c.setConfigValue(id, 'hosts', ['a', 'b', 'c', 'd']),
      PluginConfigWrite.invalidValue,
    );
    expect(
      await c.setConfigValue(id, 'regions', ['moon']),
      PluginConfigWrite.invalidValue,
    );
  });

  test('a map past the size cap is tooLarge', () async {
    final id = await install([_list, _map]);
    final big = {for (var i = 0; i < 50; i++) 'k$i': 'x' * 2000};
    expect(
      await c.setConfigValue(id, 'headers', big),
      PluginConfigWrite.tooLarge,
    );
  });

  test('a number sent as text is refused', () async {
    final id = await install([_number]);
    expect(
      await c.setConfigValue(id, 'limit', '10'),
      PluginConfigWrite.invalidValue,
    );
    expect(await c.configForRun(id), isEmpty);
  });

  test('a stored string is dropped when the field becomes a number', () async {
    final id = await install([_text(PluginInputFormat.text)]);
    await c.setConfigValue(id, 'k', '10');
    await update(id, [
      const PluginConfigField(
        key: 'k',
        title: 'K',
        mode: PluginConfigMode.input,
        inputFormat: PluginInputFormat.number,
      ),
    ]);
    expect(await c.storedConfig(id), isEmpty);
    expect(await c.configForRun(id), isEmpty);
  });

  test('writes issued one after another land in that order', () async {
    final id = await install([_text(PluginInputFormat.text)]);
    final first = c.setConfigValue(id, 'k', 'a');
    final second = c.setConfigValue(id, 'k', 'b');
    await Future.wait([first, second]);
    expect(await c.storedConfig(id), {'k': 'b'});
  });

  test('a secret over 2000 characters reads absent', () async {
    final id = await install([_text(PluginInputFormat.secret)]);
    env.secrets.values['lyrics_plugin.$id.k'] = 'x' * 2001;
    expect(await c.configForRun(id), isEmpty);
  });

  test('update drops a value whose format changed', () async {
    final id = await install([_text(PluginInputFormat.text)]);
    await c.setConfigValue(id, 'k', 'hello');
    await update(id, [_text(PluginInputFormat.multiline)]);
    expect(await c.storedConfig(id), isEmpty);
  });

  test('update keeps a value that still fits, drops an unfit one', () async {
    final id = await install([_text(PluginInputFormat.text)]);
    await c.setConfigValue(id, 'k', 'hello');
    await update(id, [_text(PluginInputFormat.text, maxLength: 10)]);
    expect(await c.storedConfig(id), {'k': 'hello'});
    await update(id, [_text(PluginInputFormat.text, maxLength: 3)]);
    expect(await c.storedConfig(id), isEmpty);
  });

  test('update moves text into a secret', () async {
    final id = await install([_text(PluginInputFormat.text)]);
    await c.setConfigValue(id, 'k', 'hello');
    await update(id, [_text(PluginInputFormat.secret)]);
    expect(env.secrets.values['lyrics_plugin.$id.k'], 'hello');
    expect(await c.storedConfig(id), isEmpty);
  });

  test('update moves only plain text into a secret', () async {
    const select = PluginConfigField(
      key: 'k',
      title: 'K',
      mode: PluginConfigMode.select,
      options: [PluginConfigOption(value: 'abc', title: 'abc')],
    );
    for (final from in [select, _text(PluginInputFormat.multiline)]) {
      final id = await install([from]);
      await c.setConfigValue(id, 'k', from == select ? 'abc' : 'multi');
      await update(id, [_text(PluginInputFormat.secret)]);
      expect(env.secrets.values, isEmpty);
      expect(await c.storedConfig(id), isEmpty);
      await env.controller.uninstall(id);
    }
  });

  test('an over-long stored secret counts as none', () async {
    final id = await install([_text(PluginInputFormat.secret)]);
    env.secrets.values['lyrics_plugin.$id.k'] = 'x' * 2001;
    expect(await c.hasSecret(id, 'k'), isFalse);
  });

  test('a secret of exactly 2000 characters counts', () async {
    final id = await install([_text(PluginInputFormat.secret)]);
    env.secrets.values['lyrics_plugin.$id.k'] = 'x' * 2000;
    expect(await c.hasSecret(id, 'k'), isTrue);
  });
}
