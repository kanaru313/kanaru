import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_controller.dart';

import '../../../database/lyrics_plugin_test_helpers.dart';
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

  int zipRequests() =>
      env.server.requests.where((r) => r.uri.path == '/demo.zip').length;

  /// Makes every zip answer take a moment, so calls overlap.
  void slowZips() {
    env.server.handler = (request) async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final body = env.routes[request.uri.path];
      if (body == null) {
        request.response.statusCode = 404;
      } else {
        request.response.add(body);
      }
      await request.response.close();
    };
  }

  Future<void> publish(int version) async {
    env.serveCatalog([entryJson(version: version)]);
    env.routes['/demo.zip'] = pluginZip(version: version);
    await env.repos.refreshAll();
  }

  group('what an install did', () {
    test('new, over a live plugin, and over a removed one', () async {
      final first = await env.repos.install(catalogUrl, 'demo');
      expect((first as RepoPluginDone).change, RepoPluginChange.installed);

      // The double tap or the page left open: a live plugin is updated, and
      // the result says so, so the app never offers Undo for it.
      final second = await env.repos.install(catalogUrl, 'demo');
      expect((second as RepoPluginDone).change, RepoPluginChange.updated);
      expect(second.record.installId, first.record.installId);

      // A reference (saved lyrics) keeps the removed record to revive.
      await seedPluginReferences(env.store.db, first.record.installId);
      await env.store.controller.uninstall(first.record.installId);
      final third = await env.repos.install(catalogUrl, 'demo');
      expect((third as RepoPluginDone).change, RepoPluginChange.revived);
      expect(third.record.installId, first.record.installId);
    });

    test('an update says updated', () async {
      final id = ((await env.repos.install(
        catalogUrl,
        'demo',
      )) as RepoPluginDone).record.installId;
      await publish(4);
      final done = await env.repos.update(id) as RepoPluginDone;
      expect(done.change, RepoPluginChange.updated);
    });
  });

  group('one run per plugin', () {
    test('two installs at once download and write once', () async {
      slowZips();
      final results = await Future.wait([
        env.repos.install(catalogUrl, 'demo'),
        env.repos.install(catalogUrl, 'demo'),
      ]);
      expect(identical(results[0], results[1]), isTrue);
      expect((results[0] as RepoPluginDone).change, RepoPluginChange.installed);
      expect(zipRequests(), 1);
      expect(await env.store.controller.watchRecords().first, hasLength(1));
    });

    test('two updates at once share one download', () async {
      final id = ((await env.repos.install(
        catalogUrl,
        'demo',
      )) as RepoPluginDone).record.installId;
      await publish(4);
      slowZips();
      final before = zipRequests();
      final a = env.repos.update(id);
      final b = env.repos.update(id);
      expect(env.repos.updating, {id});
      final results = await Future.wait([a, b]);
      expect(identical(results[0], results[1]), isTrue);
      expect(results[0], isA<RepoPluginDone>());
      expect(zipRequests() - before, 1);
      expect(env.repos.updating, isEmpty);
    });

    test('an update during update all is the same run', () async {
      final id = ((await env.repos.install(
        catalogUrl,
        'demo',
      )) as RepoPluginDone).record.installId;
      await publish(4);
      slowZips();
      final before = zipRequests();
      final all = env.repos.updateAll();
      final one = env.repos.update(id);
      expect(await one, isA<RepoPluginDone>());
      final outcomes = await all;
      expect(zipRequests() - before, 1);
      // Update all either shared the running update or found it done.
      expect(
        outcomes.every((o) => o.result is RepoPluginDone),
        isTrue,
        reason: '$outcomes',
      );
      expect(
        (await env.store.controller.watchRecords().first).single.version,
        4,
      );
    });

    test('two update-all calls share one run and report each plugin', () async {
      final id = ((await env.repos.install(
        catalogUrl,
        'demo',
      )) as RepoPluginDone).record.installId;
      await publish(4);
      slowZips();
      final before = zipRequests();
      final seen = <String>[];
      final sub = env.repos.updateOutcomes.listen((o) => seen.add(o.installId));
      final a = env.repos.updateAll();
      final b = env.repos.updateAll();
      expect(identical(a, b), isTrue);
      final outcomes = await a;
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(outcomes.map((o) => o.installId), [id]);
      expect(seen, [id]);
      expect(zipRequests() - before, 1);
      expect(env.repos.updating, isEmpty);
    });
  });

  group('storage failures are results', () {
    Future<void> abort(String table, String when) =>
        env.store.db.customStatement(
          'CREATE TRIGGER fail_write $when ON $table '
          "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
        );

    test('a failing write on install is storage and leaves nothing', () async {
      await abort('lyrics_plugins', 'BEFORE INSERT');
      final result = await env.repos.install(catalogUrl, 'demo');
      expect(failureOf(result), RepoPluginFailure.storage);
      expect(await env.store.controller.watchRecords().first, isEmpty);
    });

    test('a failing write on update is storage and keeps the old', () async {
      final id = ((await env.repos.install(
        catalogUrl,
        'demo',
      )) as RepoPluginDone).record.installId;
      await publish(4);
      await abort('lyrics_plugins', 'BEFORE UPDATE');
      expect(failureOf(await env.repos.update(id)), RepoPluginFailure.storage);
      expect(
        (await env.store.controller.watchRecords().first).single.version,
        3,
      );
      expect(env.repos.updating, isEmpty);
    });

    test('update all records the failure and goes on', () async {
      env.serveCatalog([
        entryJson(),
        entryJson(slug: 'two', name: 'Two', path: 'two.zip'),
      ]);
      env.routes['/two.zip'] = pluginZip(name: 'Two');
      await env.repos.refreshAll();
      for (final slug in ['demo', 'two']) {
        await env.repos.install(catalogUrl, slug);
      }
      env.serveCatalog([
        entryJson(version: 4),
        entryJson(slug: 'two', name: 'Two', version: 4, path: 'two.zip'),
      ]);
      env.routes['/demo.zip'] = pluginZip(version: 4);
      env.routes['/two.zip'] = pluginZip(name: 'Two', version: 4);
      await env.repos.refreshAll();
      await env.store.db.customStatement(
        'CREATE TRIGGER fail_write BEFORE UPDATE ON lyrics_plugins '
        "WHEN NEW.repo_slug = 'demo' "
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );

      final outcomes = await env.repos.updateAll();
      expect(outcomes.map((o) => o.name), ['Demo', 'Two']);
      expect(failureOf(outcomes[0].result), RepoPluginFailure.storage);
      expect(outcomes[1].result, isA<RepoPluginDone>());
    });

    test('a closed database never throws', () async {
      final id = ((await env.repos.install(
        catalogUrl,
        'demo',
      )) as RepoPluginDone).record.installId;
      await env.store.db.close();
      expect(
        failureOf(await env.repos.install(catalogUrl, 'demo')),
        RepoPluginFailure.storage,
      );
      expect(failureOf(await env.repos.update(id)), RepoPluginFailure.storage);
      expect(await env.repos.updateAll(), isEmpty);
      expect(await env.repos.refreshAll(), isEmpty);
      final added = await env.repos.add('http://other.lan/c.json');
      expect(added, isA<AddRepoFailed>());
    });
  });
}
