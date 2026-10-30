import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_problem.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_controller.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';

import '../../../database/lyrics_plugin_test_helpers.dart';
import '../store/store_test_env.dart' show testPackage;
import 'repo_controller_env.dart';

RepoPluginFailure? failureOf(RepoPluginResult r) =>
    r is RepoPluginFailed ? r.failure : null;

void main() {
  late RepoEnv env;

  setUp(() async {
    env = await RepoEnv.create();
    env.serveCatalog([entryJson()]);
    env.routes['/demo.zip'] = pluginZip();
    await env.repos.add(catalogUrl);
  });
  tearDown(() => env.dispose());

  Future<int> recordCount() async =>
      (await env.store.db.watchLyricsPluginRecords().first).length;

  group('install', () {
    test('installs from the zip manifest with the repo as source', () async {
      final done = await env.repos.install(catalogUrl, 'demo');
      final record = (done as RepoPluginDone).record;
      expect(record.name, 'Demo');
      expect(record.version, 3);
      expect(record.sourceName, 'Official');
      expect(record.repoUrl, catalogUrl);
      expect(record.repoSlug, 'demo');
      expect(env.server.requests.last.uri.path, '/demo.zip');
    });

    test('hosts are compared as sets, in any order', () async {
      env.serveCatalog([
        entryJson(hosts: ['a.example.com', 'b.example.com']),
      ]);
      await env.repos.refreshAll();
      env.routes['/demo.zip'] = pluginZip(
        hosts: ['b.example.com', 'a.example.com'],
      );
      expect(
        await env.repos.install(catalogUrl, 'demo'),
        isA<RepoPluginDone>(),
      );
    });

    test('a different version is a mismatch and installs nothing', () async {
      env.routes['/demo.zip'] = pluginZip(version: 4);
      final result = await env.repos.install(catalogUrl, 'demo');
      expect(failureOf(result), RepoPluginFailure.catalogMismatch);
      final declared = (result as RepoPluginFailed).packageDeclared;
      expect(declared?.version, 4);
      expect(declared?.hosts, ['music.example.com']);
      expect(await recordCount(), 0);
      expect(env.store.root.existsSync(), isFalse);
    });

    test('different hosts are a mismatch (extra, missing, other)', () async {
      for (final hosts in [
        ['music.example.com', 'extra.example.com'],
        ['other.example.com'],
      ]) {
        env.routes['/demo.zip'] = pluginZip(hosts: hosts);
        final result = await env.repos.install(catalogUrl, 'demo');
        expect(
          failureOf(result),
          RepoPluginFailure.catalogMismatch,
          reason: '$hosts',
        );
        final declared = (result as RepoPluginFailed).packageDeclared;
        expect(declared?.version, 3);
        expect(declared?.hosts, hosts);
      }
      env.serveCatalog([
        entryJson(hosts: ['music.example.com', 'extra.example.com']),
      ]);
      await env.repos.refreshAll();
      env.routes['/demo.zip'] = pluginZip();
      expect(
        failureOf(await env.repos.install(catalogUrl, 'demo')),
        RepoPluginFailure.catalogMismatch,
      );
      expect(await recordCount(), 0);
    });

    test('maps unknown repo, entry, newer api, download and bad zip', () async {
      expect(
        failureOf(await env.repos.install('http://nope.lan/x', 'demo')),
        RepoPluginFailure.unknownRepo,
      );
      expect(
        failureOf(await env.repos.install(catalogUrl, 'missing')),
        RepoPluginFailure.unknownEntry,
      );
      env.failing['/demo.zip'] = 404;
      final download =
          await env.repos.install(catalogUrl, 'demo') as RepoPluginFailed;
      expect(download.failure, RepoPluginFailure.download);
      expect(download.fetchError?.kind, RepoFetchErrorKind.notFound);
      env.failing.clear();
      env.routes['/demo.zip'] = 'not a zip'.codeUnits;
      final bad =
          await env.repos.install(catalogUrl, 'demo') as RepoPluginFailed;
      expect(bad.failure, RepoPluginFailure.rejected);
      expect(bad.problem, isA<PluginPackageProblem>());
      env.serveCatalog([entryJson(apiVersion: 2)]);
      await env.repos.refreshAll();
      expect(
        failureOf(await env.repos.install(catalogUrl, 'demo')),
        RepoPluginFailure.needsNewerApp,
      );
      expect(await recordCount(), 0);
    });

    test('over a removed record revives the old install id', () async {
      final first = (await env.repos.install(
        catalogUrl,
        'demo',
      ) as RepoPluginDone).record;
      await seedPluginReferences(env.store.db, first.installId);
      await env.store.controller.uninstall(first.installId);
      final removed = await env.store.controller.watchRecords().first;
      expect(removed.single.isRemoved, isTrue);

      final again = (await env.repos.install(
        catalogUrl,
        'demo',
      ) as RepoPluginDone).record;
      expect(again.installId, first.installId);
      expect(again.isRemoved, isFalse);
      expect(await recordCount(), 1);
    });

    test(
      'over a live record updates it and refuses an older package',
      () async {
        final first = (await env.repos.install(
          catalogUrl,
          'demo',
        ) as RepoPluginDone).record;
        final same =
            await env.repos.install(catalogUrl, 'demo') as RepoPluginDone;
        expect(same.record.installId, first.installId);

        env.serveCatalog([entryJson(version: 2)]);
        env.routes['/demo.zip'] = pluginZip(version: 2);
        await env.repos.refreshAll();
        final older =
            await env.repos.install(catalogUrl, 'demo') as RepoPluginFailed;
        expect(older.failure, RepoPluginFailure.refused);
        expect(older.refusal, PluginUpdateRefusal.olderVersion);
      },
    );

    test('secrets that cannot be cleared are reported', () async {
      env.routes['/demo.zip'] = pluginZip(
        config: {
          'token': {'title': 'Token', 'mode': 'input', 'format': 'secret'},
        },
      );
      final first = (await env.repos.install(
        catalogUrl,
        'demo',
      ) as RepoPluginDone).record;
      await seedPluginReferences(env.store.db, first.installId);
      await env.store.controller.uninstall(first.installId);
      env.store.secrets.failing = true;
      expect(
        failureOf(await env.repos.install(catalogUrl, 'demo')),
        RepoPluginFailure.secretsUnavailable,
      );
      expect(
        (await env.store.controller.watchRecords().first).single.isRemoved,
        isTrue,
      );
    });
  });

  group('update', () {
    final config = {
      'note': {'title': 'Note', 'mode': 'input'},
    };

    Future<String> installV3() async {
      env.routes['/demo.zip'] = pluginZip(config: config);
      final done =
          await env.repos.install(catalogUrl, 'demo') as RepoPluginDone;
      return done.record.installId;
    }

    Future<void> publish(int version, {List<String>? hosts}) async {
      env.serveCatalog([
        entryJson(version: version, hosts: hosts ?? ['music.example.com']),
      ]);
      env.routes['/demo.zip'] = pluginZip(
        version: version,
        hosts: hosts ?? ['music.example.com'],
        config: config,
      );
      await env.repos.refreshAll();
    }

    test('keeps the install id, the config and the on/off state', () async {
      final id = await installV3();
      await env.store.controller.setConfigValue(id, 'note', 'hello');
      await env.store.controller.setEnabled(id, false);
      await publish(4, hosts: ['music.example.com', 'new.example.com']);

      final done = await env.repos.update(id) as RepoPluginDone;
      expect(done.record.installId, id);
      expect(done.record.version, 4);
      expect(
        done.record.hosts,
        hasLength(2),
        reason: 'no prompt for new hosts',
      );
      expect(await env.store.controller.storedConfig(id), {'note': 'hello'});
      final prefs = await env.store.db.watchLyricsSourcePrefs().first;
      expect(prefs.single.enabled, isFalse);
    });

    test('is refused for a file plugin, a removed repo and no news', () async {
      final file = await env.store.controller.installPackage(
        testPackage(name: 'File'),
        const PluginInstallSource.file('f.zip'),
      );
      expect(
        failureOf(await env.repos.update(file.installId)),
        RepoPluginFailure.notFromRepo,
      );
      final id = await installV3();
      expect(
        failureOf(await env.repos.update(id)),
        RepoPluginFailure.noNewerVersion,
      );
      await publish(2);
      expect(
        failureOf(await env.repos.update(id)),
        RepoPluginFailure.noNewerVersion,
        reason: 'older catalog version',
      );
      await publish(4);
      await env.repos.remove(catalogUrl);
      expect(
        failureOf(await env.repos.update(id)),
        RepoPluginFailure.unknownRepo,
      );
      expect(
        failureOf(await env.repos.update('plugin-missingxxxxx')),
        RepoPluginFailure.gone,
      );
    });

    test('a newer api version is not offered', () async {
      final id = await installV3();
      env.serveCatalog([entryJson(version: 9, apiVersion: 2)]);
      await env.repos.refreshAll();
      expect(
        failureOf(await env.repos.update(id)),
        RepoPluginFailure.needsNewerApp,
      );
    });

    test('a mismatching package changes nothing', () async {
      final id = await installV3();
      await publish(4);
      env.routes['/demo.zip'] = pluginZip(version: 5, config: config);
      expect(
        failureOf(await env.repos.update(id)),
        RepoPluginFailure.catalogMismatch,
      );
      final records = await env.store.controller.watchRecords().first;
      expect(records.single.version, 3);
    });

    test('updateAll goes one by one over plugins with an update', () async {
      env.serveCatalog([
        entryJson(),
        entryJson(slug: 'two', name: 'Two', path: 'two.zip'),
        entryJson(slug: 'three', name: 'Three', path: 'three.zip'),
      ]);
      env.routes['/two.zip'] = pluginZip(name: 'Two');
      env.routes['/three.zip'] = pluginZip(name: 'Three');
      env.routes['/demo.zip'] = pluginZip();
      await env.repos.refreshAll();
      for (final slug in ['demo', 'two', 'three']) {
        await env.repos.install(catalogUrl, slug);
      }
      env.serveCatalog([
        entryJson(version: 4),
        entryJson(slug: 'two', name: 'Two', path: 'two.zip'),
        entryJson(slug: 'three', name: 'Three', version: 5, path: 'three.zip'),
      ]);
      env.routes['/demo.zip'] = pluginZip(version: 4);
      env.routes['/three.zip'] = pluginZip(name: 'Three', version: 5);
      await env.repos.refreshAll();

      var active = 0;
      var peak = 0;
      env.server.handler = (request) async {
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        request.response.add(env.routes[request.uri.path] ?? const []);
        await request.response.close();
        active--;
      };
      final outcomes = await env.repos.updateAll();
      expect(outcomes.map((o) => o.name), ['Demo', 'Three']);
      expect(outcomes.every((o) => o.result is RepoPluginDone), isTrue);
      expect(peak, 1);
      expect(await env.repos.updateAll(), isEmpty);
    });
  });
}
