import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';

import 'lyrics_plugin_test_helpers.dart';

void main() {
  late LibraryDatabase db;

  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('records', () {
    test('insert writes the record and an empty data row', () async {
      await db.insertLyricsPlugin('plugin-a', pluginSpec(), now: 100);
      final row = (await db.lyricsPluginById('plugin-a'))!;
      expect(row.name, 'Demo');
      expect(row.hosts, '["api.example.com"]');
      expect(row.sourceKind, 'file');
      expect(row.installedAt, 100);
      expect(row.updatedAt, 100);
      expect(row.removedAt, isNull);
      final data = (await db.lyricsPluginDataFor('plugin-a'))!;
      expect(data.configValues, '{}');
      expect(data.storage, '{}');
    });

    test('the same repo url and slug cannot be installed twice', () async {
      final spec = pluginSpec(repoUrl: 'https://r/x', repoSlug: 'demo');
      await db.insertLyricsPlugin('plugin-a', spec, now: 1);
      await expectLater(
        db.insertLyricsPlugin('plugin-b', spec, now: 2),
        throwsA(isA<Exception>()),
      );
      expect(await countRows(db, 'lyrics_plugins'), 1);
      expect(await countRows(db, 'lyrics_plugin_data'), 1);
      expect(
        (await db.lyricsPluginByRepo('https://r/x', 'demo'))!.installId,
        'plugin-a',
      );
      expect(await db.lyricsPluginByRepo('https://r/x', 'other'), isNull);
    });

    test('file installs without a repo url may repeat', () async {
      await db.insertLyricsPlugin('plugin-a', pluginSpec(), now: 1);
      await db.insertLyricsPlugin('plugin-b', pluginSpec(), now: 2);
      expect(await countRows(db, 'lyrics_plugins'), 2);
    });

    test('watch lists removed records too', () async {
      await db.insertLyricsPlugin('plugin-a', pluginSpec(), now: 1);
      await seedPluginReferences(db, 'plugin-a');
      await db.uninstallLyricsPlugin('plugin-a', now: 5);
      final rows = await db.watchLyricsPluginRecords().first;
      expect(rows.single.removedAt, 5);
    });

    test('revive keeps the id, clears removed_at and resets data', () async {
      final spec = pluginSpec(repoUrl: 'https://r/x', repoSlug: 'demo');
      await db.insertLyricsPlugin('plugin-a', spec, now: 1);
      await db.setLyricsPluginConfigValues('plugin-a', {'k': 'v'});
      await seedPluginReferences(db, 'plugin-a');
      await db.uninstallLyricsPlugin('plugin-a', now: 5);

      final revived = await db.reviveLyricsPlugin(
        'plugin-a',
        pluginSpec(
          version: 2,
          packageDir: 'plugin-a/v2-9',
          repoUrl: 'https://r/x',
          repoSlug: 'demo',
        ),
        now: 9,
      );
      expect(revived, 9);
      final row = (await db.lyricsPluginById('plugin-a'))!;
      expect(row.removedAt, isNull);
      expect(row.version, 2);
      expect(row.packageDir, 'plugin-a/v2-9');
      expect(row.installedAt, 9);
      expect(row.updatedAt, 9);
      expect((await db.lyricsPluginDataFor('plugin-a'))!.configValues, '{}');
      // The saved lyrics are still there under the same id.
      expect(await countRows(db, 'online_lyrics'), 1);
    });

    test('revive of a live or missing record writes nothing', () async {
      await db.insertLyricsPlugin('plugin-a', pluginSpec(), now: 1);
      expect(
        await db.reviveLyricsPlugin('plugin-a', pluginSpec(name: 'X'), now: 2),
        isNull,
      );
      expect(
        await db.reviveLyricsPlugin('plugin-z', pluginSpec(), now: 2),
        isNull,
      );
      expect((await db.lyricsPluginById('plugin-a'))!.name, 'Demo');
    });

    test(
      'revive moves updated_at forward even in the same millisecond',
      () async {
        await db.insertLyricsPlugin('plugin-a', pluginSpec(), now: 100);
        await seedPluginReferences(db, 'plugin-a');
        await db.uninstallLyricsPlugin('plugin-a', now: 100);
        final updatedAt = await db.reviveLyricsPlugin(
          'plugin-a',
          pluginSpec(),
          now: 100,
        );
        expect(updatedAt, 101);
        // A run that began before the uninstall must not write now.
        expect(
          await db.setLyricsPluginStorage('plugin-a', {
            'a': 1,
          }, expectedUpdatedAt: 100),
          LyricsPluginWrite.skipped,
        );
        expect(
          await db.setLyricsPluginStorage('plugin-a', {
            'a': 1,
          }, expectedUpdatedAt: 101),
          LyricsPluginWrite.written,
        );
      },
    );

    test('revive does not bring back a preference', () async {
      await db.insertLyricsPlugin('plugin-a', pluginSpec(), now: 1);
      await db.setLyricsSourceEnabled('plugin-a', false);
      await seedPluginReferences(db, 'plugin-a');
      await db.uninstallLyricsPlugin('plugin-a', now: 2);
      await db.setLyricsSourceEnabled('plugin-a', false);
      await db.reviveLyricsPlugin('plugin-a', pluginSpec(), now: 3);
      expect(await db.watchLyricsSourcePrefs().first, isEmpty);
    });

    test('insert and revive reject an id without the plugin prefix', () async {
      await expectLater(
        db.insertLyricsPlugin('lrclib', pluginSpec(), now: 1),
        throwsArgumentError,
      );
      await expectLater(
        db.reviveLyricsPlugin('other', pluginSpec(), now: 1),
        throwsArgumentError,
      );
      expect(await countRows(db, 'lyrics_plugins'), 0);
      expect(await countRows(db, 'lyrics_plugin_data'), 0);
    });

    test(
      'data writes do not emit on the record or preference streams',
      () async {
        await db.insertLyricsPlugin('plugin-a', pluginSpec(), now: 100);
        var records = 0;
        var prefs = 0;
        final subs = [
          db.watchLyricsPluginRecords().listen((_) => records++),
          db.watchLyricsSourcePrefs().listen((_) => prefs++),
        ];
        await pumpEventQueue();
        final (r0, p0) = (records, prefs);
        await db.setLyricsPluginStorage('plugin-a', {
          's': 1,
        }, expectedUpdatedAt: 100);
        await db.setLyricsPluginConfigValues('plugin-a', {'c': 1});
        await pumpEventQueue();
        for (final s in subs) {
          await s.cancel();
        }
        expect((records, prefs), (r0, p0));
      },
    );

    test('package dirs list live records only', () async {
      await db.insertLyricsPlugin('plugin-a', pluginSpec(), now: 1);
      await db.insertLyricsPlugin(
        'plugin-b',
        pluginSpec(packageDir: 'plugin-b/v1-2'),
        now: 2,
      );
      await seedPluginReferences(db, 'plugin-b');
      await db.uninstallLyricsPlugin('plugin-b', now: 3);
      expect(await db.lyricsPluginPackageDirs(), {'plugin-a/v1-100'});
    });
  });

  group('package switch', () {
    setUp(() async {
      await db.insertLyricsPlugin('plugin-a', pluginSpec(), now: 100);
      await db.setLyricsPluginConfigValues('plugin-a', {'k': 'v'});
      await db.setLyricsPluginStorage('plugin-a', {
        's': 1,
      }, expectedUpdatedAt: 100);
      await db.setLyricsSourceEnabled('plugin-a', false);
    });

    test('changes version, schema, hosts and dir together', () async {
      final updatedAt = await db.switchLyricsPluginPackage(
        'plugin-a',
        pluginSpec(
          version: 2,
          packageDir: 'plugin-a/v2-200',
          configSchema: '[{"key":"a"}]',
          hosts: const ['b.example.com'],
        ),
        now: 200,
      );
      expect(updatedAt, 200);
      final row = (await db.lyricsPluginById('plugin-a'))!;
      expect(row.version, 2);
      expect(row.packageDir, 'plugin-a/v2-200');
      expect(row.configSchema, '[{"key":"a"}]');
      expect(row.hosts, '["b.example.com"]');
      expect(row.updatedAt, 200);
      expect(row.installedAt, 100);
    });

    test('keeps config, storage and preferences', () async {
      await db.switchLyricsPluginPackage('plugin-a', pluginSpec(), now: 200);
      final data = (await db.lyricsPluginDataFor('plugin-a'))!;
      expect(data.configValues, '{"k":"v"}');
      expect(data.storage, '{"s":1}');
      expect((await db.watchLyricsSourcePrefs().first).single.enabled, isFalse);
    });

    test('updated_at always moves forward', () async {
      final updatedAt = await db.switchLyricsPluginPackage(
        'plugin-a',
        pluginSpec(),
        now: 100,
      );
      expect(updatedAt, 101);
    });

    test('a failure leaves the old package fully in place', () async {
      await db.customStatement(
        'CREATE TRIGGER block_switch BEFORE UPDATE ON lyrics_plugins '
        "BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );
      await expectLater(
        db.switchLyricsPluginPackage(
          'plugin-a',
          pluginSpec(version: 2, packageDir: 'plugin-a/v2-200'),
          now: 200,
        ),
        throwsA(isA<Exception>()),
      );
      final row = (await db.lyricsPluginById('plugin-a'))!;
      expect(row.version, 1);
      expect(row.packageDir, 'plugin-a/v1-100');
      expect(row.updatedAt, 100);
    });

    test('a removed or missing record is not switched', () async {
      await seedPluginReferences(db, 'plugin-a');
      await db.uninstallLyricsPlugin('plugin-a', now: 150);
      expect(
        await db.switchLyricsPluginPackage('plugin-a', pluginSpec(), now: 200),
        isNull,
      );
      expect(
        await db.switchLyricsPluginPackage('plugin-z', pluginSpec(), now: 200),
        isNull,
      );
      expect((await db.lyricsPluginById('plugin-a'))!.updatedAt, 100);
    });
  });
}
