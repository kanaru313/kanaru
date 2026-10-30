import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:logging/logging.dart';

import 'store_test_env.dart';

const toggleField = PluginConfigField(
  key: 'strict',
  title: 'Strict',
  mode: PluginConfigMode.toggle,
  defaultValue: true,
);
const numberField = PluginConfigField(
  key: 'limit',
  title: 'Limit',
  mode: PluginConfigMode.input,
  inputFormat: PluginInputFormat.number,
);
const secretValue = 'sekrit-value-4711';

void main() {
  late StoreEnv env;
  late LyricsPluginsController controller;
  late List<LogRecord> logs;
  late Level? oldLevel;

  Future<LyricsPluginRecord> install(List<PluginConfigField> config) =>
      controller.installPackage(testPackage(config: config), testRepoSource);

  Future<String> configValuesColumn(String id) async =>
      (await env.db.lyricsPluginDataFor(id))!.configValues;

  setUp(() async {
    env = await StoreEnv.create();
    controller = env.controller;
    logs = [];
    oldLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen(logs.add);
  });
  tearDown(() async {
    Logger.root.level = oldLevel!;
    await env.dispose();
  });

  test('a secret reaches only the secret store', () async {
    final p = await install([secretField, regionField]);
    expect(
      await controller.setConfigValue(p.installId, 'token', secretValue),
      PluginConfigWrite.written,
    );
    await controller.setConfigValue(p.installId, 'region', 'us');
    expect(env.secrets.values, {
      'lyrics_plugin.${p.installId}.token': secretValue,
    });
    final column = await configValuesColumn(p.installId);
    expect(column, isNot(contains(secretValue)));
    expect(column, contains('"region":"us"'));
    final rows = await env.db
        .customSelect('SELECT * FROM lyrics_plugin_data')
        .get();
    expect(rows.any((r) => '${r.data}'.contains(secretValue)), isFalse);
  });

  test('configForRun merges values, defaults and secrets', () async {
    final p = await install([secretField, regionField, toggleField]);
    await controller.setConfigValue(p.installId, 'token', secretValue);
    expect(await controller.configForRun(p.installId), {
      'token': secretValue,
      'region': 'eu', // default
      'strict': 'true', // default
    });
    await controller.setConfigValue(p.installId, 'strict', false);
    await controller.setConfigValue(p.installId, 'region', 'us');
    final merged = await controller.configForRun(p.installId);
    expect(merged['strict'], 'false');
    expect(merged['region'], 'us');
    await controller.setConfigValue(p.installId, 'region', '');
    expect((await controller.configForRun(p.installId))['region'], 'eu');
  });

  test('values are checked against the form', () async {
    final p = await install([regionField, numberField, toggleField]);
    Future<PluginConfigWrite> set(String key, Object? v) =>
        controller.setConfigValue(p.installId, key, v);
    expect(await set('region', 'moon'), PluginConfigWrite.invalidValue);
    expect(await set('limit', 'ten'), PluginConfigWrite.invalidValue);
    expect(await set('limit', '10'), PluginConfigWrite.written);
    expect(await set('strict', 'yes'), PluginConfigWrite.invalidValue);
    expect(await set('nope', 'x'), PluginConfigWrite.unknownKey);
    expect(
      await controller.setConfigValue('plugin-zzzzzzzzzzzz', 'region', 'eu'),
      PluginConfigWrite.unknownKey,
    );
  });

  test('a secret is read from the store once per session', () async {
    final p = await install([secretField]);
    env.secrets.values['lyrics_plugin.${p.installId}.token'] = secretValue;
    for (var i = 0; i < 3; i++) {
      expect(await controller.configForRun(p.installId), {
        'token': secretValue,
      });
    }
    expect(env.secrets.reads, 1);
    await controller.setConfigValue(p.installId, 'token', 'other-secret');
    expect(
      (await controller.configForRun(p.installId))['token'],
      'other-secret',
    );
    expect(env.secrets.reads, 1, reason: 'a write fills the cache');
  });

  test('a locked store reads as absent with one warning', () async {
    final p = await install([
      secretField,
      const PluginConfigField(
        key: 'second',
        title: 'Second',
        mode: PluginConfigMode.input,
        inputFormat: PluginInputFormat.secret,
      ),
    ]);
    env.secrets.failing = true;
    expect(await controller.configForRun(p.installId), isEmpty);
    expect(await controller.configForRun(p.installId), isEmpty);
    final warnings = logs.where(
      (r) => r.level == Level.WARNING && r.message.contains('Secret store'),
    );
    expect(warnings, hasLength(1));
    expect(
      await controller.setConfigValue(p.installId, 'token', secretValue),
      PluginConfigWrite.secretStoreFailed,
    );
  });

  test('update moves a text value into the secret store', () async {
    final p = await install([textField]);
    await controller.setConfigValue(p.installId, 'token', secretValue);
    expect(await configValuesColumn(p.installId), contains(secretValue));
    await controller.updatePackage(
      p.installId,
      testPackage(version: 2, config: [secretField]),
    );
    expect(await configValuesColumn(p.installId), isNot(contains(secretValue)));
    expect(
      env.secrets.values['lyrics_plugin.${p.installId}.token'],
      secretValue,
    );
    expect((await controller.configForRun(p.installId))['token'], secretValue);
  });

  test('update drops the store entry of a secret that became text', () async {
    final p = await install([secretField]);
    await controller.setConfigValue(p.installId, 'token', secretValue);
    await controller.updatePackage(
      p.installId,
      testPackage(version: 2, config: [textField]),
    );
    expect(env.secrets.values, isEmpty);
    expect(await controller.configForRun(p.installId), isEmpty);
  });

  test('update deletes removed keys and values that no longer fit', () async {
    final p = await install([secretField, regionField]);
    await controller.setConfigValue(p.installId, 'token', secretValue);
    await controller.setConfigValue(p.installId, 'region', 'us');
    await controller.updatePackage(
      p.installId,
      testPackage(
        version: 2,
        config: [
          const PluginConfigField(
            key: 'region',
            title: 'Region',
            mode: PluginConfigMode.select,
            options: [PluginConfigOption(value: 'eu', title: 'EU')],
          ),
        ],
      ),
    );
    expect(env.secrets.values, isEmpty);
    expect(await controller.storedConfig(p.installId), isEmpty);
  });

  test('no log line carries a secret value', () async {
    final p = await install([secretField]);
    await controller.setConfigValue(p.installId, 'token', secretValue);
    env.secrets.failing = true; // provoke the failure paths
    await controller.configForRun(p.installId);
    await controller.updatePackage(
      p.installId,
      testPackage(version: 2, config: [textField]),
    );
    await controller.uninstall(p.installId);
    expect(logs, isNotEmpty);
    for (final r in logs) {
      expect(
        '${r.message} ${r.error} ${r.stackTrace}',
        isNot(contains(secretValue)),
      );
    }
  });

  test('secretsUsingFallback reports the store mode', () async {
    expect(await controller.secretsUsingFallback(), isFalse);
  });

  test('clearing a secret fails visibly and the value stays', () async {
    final p = await install([secretField]);
    await controller.setConfigValue(p.installId, 'token', secretValue);
    env.secrets.failing = true;
    expect(
      await controller.setConfigValue(p.installId, 'token', ''),
      PluginConfigWrite.secretStoreFailed,
    );
    env.secrets.failing = false;
    expect(await controller.hasSecret(p.installId, 'token'), isTrue);
    expect(
      await controller.setConfigValue(p.installId, 'token', ''),
      PluginConfigWrite.written,
    );
    expect(env.secrets.values, isEmpty);
    expect(await controller.hasSecret(p.installId, 'token'), isFalse);
  });
}
