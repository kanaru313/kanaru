import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';

import '../../../database/lyrics_plugin_test_helpers.dart';
import '../package/package_test_helpers.dart';
import 'store_test_env.dart';

const repo = PluginInstallSource.repo(
  name: 'Official',
  repoUrl: 'https://repo.example.com/index.json',
  repoSlug: 'demo',
);

Future<int> dirCount(Directory root) async =>
    await root.exists() ? (await root.list().toList()).length : 0;

void main() {
  late StoreEnv env;
  setUp(() async => env = await StoreEnv.create());
  tearDown(() => env.dispose());

  test('install writes the package, the record and a source row', () async {
    final record = await env.controller.installPackage(
      testPackage(icon: [9]),
      const PluginInstallSource.file('demo.zip'),
    );
    expect(record.installId, matches(RegExp(r'^plugin-[a-z0-9]{12}$')));
    expect(record.name, 'Demo');
    expect(record.sourceName, 'demo.zip');
    expect(record.sourceKind, LyricsPluginSourceKind.file);
    expect(record.packageDir, startsWith('${record.installId}/v1-'));
    final dir = env.packageDir(record.packageDir).path;
    expect(File('$dir/plugin.json').existsSync(), isTrue);
    expect(File('$dir/icon.png').existsSync(), isTrue);
    expect(File('$dir/src/lyrics.js').readAsStringSync(), '// lyrics');
    final prefs = await env.db.watchLyricsSourcePrefs().first;
    expect(prefs.single.providerId, record.installId);
    expect(prefs.single.enabled, isTrue);
  });

  test('a second install goes last and gets its own id', () async {
    final a = await env.controller.installPackage(
      testPackage(),
      const PluginInstallSource.file('a.zip'),
    );
    final b = await env.controller.installPackage(
      testPackage(),
      const PluginInstallSource.file('a.zip'),
    );
    expect(b.installId, isNot(a.installId));
    final prefs = await env.db.watchLyricsSourcePrefs().first;
    expect(prefs.map((p) => p.providerId), [a.installId, b.installId]);
  });

  test('a database failure removes the new folder and rethrows', () async {
    await env.db.customStatement(
      'CREATE TRIGGER fail_insert BEFORE INSERT ON lyrics_plugins '
      "BEGIN SELECT RAISE(ABORT, 'boom'); END",
    );
    await expectLater(
      env.controller.installPackage(
        testPackage(),
        const PluginInstallSource.file('a.zip'),
      ),
      throwsA(anything),
    );
    expect(await dirCount(env.root), 0);
  });

  test('update keeps id, config, order and removes the old folder', () async {
    final first = await env.controller.installPackage(
      testPackage(config: [textField]),
      repo,
    );
    await env.controller.setConfigValue(first.installId, 'token', 'abc');
    final other = await env.controller.installPackage(
      testPackage(),
      const PluginInstallSource.file('b.zip'),
    );
    final updated = await env.controller.updatePackage(
      first.installId,
      testPackage(version: 2, config: [textField]),
    );
    expect(updated!.installId, first.installId);
    expect(updated.version, 2);
    expect(updated.updatedAt, greaterThan(first.updatedAt));
    expect(await env.packageDir(first.packageDir).exists(), isFalse);
    expect(await env.packageDir(updated.packageDir).exists(), isTrue);
    expect(await env.controller.storedConfig(first.installId), {
      'token': 'abc',
    });
    final prefs = await env.db.watchLyricsSourcePrefs().first;
    expect(prefs.map((p) => p.providerId), [first.installId, other.installId]);
  });

  test('a failed switch keeps the old package and removes the new', () async {
    final record = await env.controller.installPackage(testPackage(), repo);
    await env.db.customStatement(
      'CREATE TRIGGER fail_update BEFORE UPDATE ON lyrics_plugins '
      "BEGIN SELECT RAISE(ABORT, 'boom'); END",
    );
    await expectLater(
      env.controller.updatePackage(record.installId, testPackage(version: 2)),
      throwsA(anything),
    );
    final row = await env.db.lyricsPluginById(record.installId);
    expect(row!.version, 1);
    expect(await env.packageDir(row.packageDir).exists(), isTrue);
    expect(await dirCount(env.packageDir(record.installId)), 1);
  });

  test('the sweep removes a leftover folder after a simulated crash', () async {
    final record = await env.controller.installPackage(testPackage(), repo);
    final updated = (await env.controller.updatePackage(
      record.installId,
      testPackage(version: 2),
    ))!;
    // The old folder reappears, as if the process died before deleting it.
    final old = env.packageDir(record.packageDir);
    await old.create(recursive: true);
    await env.packageDir('${record.installId}/v3-1').create();
    await env.newController().ready;
    expect(await old.exists(), isFalse);
    expect(await env.packageDir('${record.installId}/v3-1').exists(), isFalse);
    expect(await env.packageDir(updated.packageDir).exists(), isTrue);
  });

  test('update of a missing or removed plugin returns null', () async {
    expect(
      await env.controller.updatePackage('plugin-zzzzzzzzzzzz', testPackage()),
      isNull,
    );
    final record = await env.controller.installPackage(testPackage(), repo);
    await seedPluginReferences(env.db, record.installId);
    await env.controller.uninstall(record.installId);
    expect(
      await env.controller.updatePackage(record.installId, testPackage()),
      isNull,
    );
    expect(await dirCount(env.root), 0);
  });

  test('reinstall from the same repo revives the id and the lyrics', () async {
    final first = await env.controller.installPackage(
      testPackage(config: [secretField]),
      repo,
    );
    await env.controller.setConfigValue(first.installId, 'token', 'sekrit');
    await seedPluginReferences(env.db, first.installId, notFound: false);
    await env.controller.uninstall(first.installId);
    env.secrets.values['lyrics_plugin.${first.installId}.token'] = 'leftover';

    final again = await env.controller.installPackage(
      testPackage(version: 2, config: [secretField]),
      repo,
    );
    expect(again.installId, first.installId);
    expect(again.isRemoved, isFalse);
    expect(again.version, 2);
    expect(again.updatedAt, greaterThan(first.updatedAt));
    expect(env.secrets.values, isEmpty, reason: 'old secrets are gone');
    expect(await env.controller.storedConfig(again.installId), isEmpty);
    expect(await countRows(env.db, 'online_lyrics'), 1);
    final prefs = await env.db.watchLyricsSourcePrefs().first;
    expect(prefs.single.enabled, isTrue);
  });

  test('installing a repo plugin that is already live updates it', () async {
    final first = await env.controller.installPackage(testPackage(), repo);
    final again = await env.controller.installPackage(
      testPackage(version: 4),
      repo,
    );
    expect(again.installId, first.installId);
    expect(again.version, 4);
    expect((await env.db.watchLyricsPluginRecords().first).length, 1);
  });

  test('update refuses a file plugin and a lower version', () async {
    final fromFile = await env.controller.installPackage(
      testPackage(version: 2),
      const PluginInstallSource.file('a.zip'),
    );
    await expectLater(
      env.controller.updatePackage(fromFile.installId, testPackage(version: 3)),
      throwsA(
        isA<PluginUpdateRefusedException>().having(
          (e) => e.reason,
          'reason',
          PluginUpdateRefusal.notFromRepo,
        ),
      ),
    );
    final fromRepo = await env.controller.installPackage(
      testPackage(version: 5),
      repo,
    );
    await expectLater(
      env.controller.updatePackage(fromRepo.installId, testPackage(version: 4)),
      throwsA(isA<PluginUpdateRefusedException>()),
    );
    final same = await env.controller.updatePackage(
      fromRepo.installId,
      testPackage(version: 5),
    );
    expect(same!.version, 5, reason: 'an equal version is allowed');
    expect((await env.db.lyricsPluginById(fromFile.installId))!.version, 2);
  });

  test('the bytes variants turn refusals into outcomes', () async {
    final fromFile = await env.controller.installPackage(
      testPackage(),
      const PluginInstallSource.file('a.zip'),
    );
    expect(
      await env.controller.updateFromBytes(fromFile.installId, validZip()),
      isA<PluginInstallRefused>(),
    );
  });

  test('a revive that cannot delete old secrets changes nothing', () async {
    final first = await env.controller.installPackage(
      testPackage(config: [secretField]),
      repo,
    );
    await seedPluginReferences(env.db, first.installId, notFound: false);
    await env.controller.uninstall(first.installId);
    env.secrets.values['lyrics_plugin.${first.installId}.token'] = 'leftover';
    env.secrets.failing = true;
    final before = await snapshotPluginTables(env.db);

    final outcome = await env.controller.installFromBytes(validZip(), repo);
    expect(outcome, isA<PluginInstallSecretsUnavailable>());
    expect(await snapshotPluginTables(env.db), before);
    expect(await dirCount(env.root), 0);

    env.secrets.failing = false;
    final retry = await env.controller.installPackage(testPackage(), repo);
    expect(retry.installId, first.installId);
    expect(env.secrets.values, isEmpty);
  });
}
