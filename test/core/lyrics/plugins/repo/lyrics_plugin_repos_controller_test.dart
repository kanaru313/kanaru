import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_controller.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';

import 'repo_controller_env.dart';

AddRepoFailure? failureOf(AddRepoResult result) =>
    result is AddRepoFailed ? result.failure : null;

void main() {
  late RepoEnv env;

  setUp(() async {
    env = await RepoEnv.create();
    env.serveCatalog([entryJson(), entryJson(slug: 'two', path: 'two.zip')]);
  });
  tearDown(() => env.dispose());

  Future<List<PluginRepo>> stored() => env.repos.watchRepos().first;

  group('add', () {
    test('stores the repo with its name, catalog and entry count', () async {
      final result = await env.repos.add(catalogUrl);
      final added = result as AddRepoAdded;
      expect(added.name, 'Official');
      expect(added.pluginCount, 2);
      expect(added.url, catalogUrl);
      final repo = (await stored()).single;
      expect(repo.url, catalogUrl);
      expect(repo.author, 'someone');
      expect(repo.error, isNull);
      expect(repo.kind, RepoAddressKind.local);
      expect(repo.catalog!.entries.map((e) => e.slug), ['demo', 'two']);
      expect(
        repo.catalog!.entries.first.path.toString(),
        'http://repo.lan:8080/demo.zip',
        reason: 'stored addresses are absolute',
      );
    });

    test('the same repo spelled differently is a duplicate', () async {
      await env.repos.add(catalogUrl);
      final requests = env.server.requests.length;
      final again = await env.repos.add(' HTTP://Repo.LAN:8080/plugins.json ');
      expect(failureOf(again), AddRepoFailure.duplicate);
      expect(env.server.requests.length, requests, reason: 'no fetch');
      expect(await stored(), hasLength(1));
    });

    test('a public address over http is refused before any request', () async {
      final result = await env.repos.add('http://example.com/plugins.json');
      expect(failureOf(result), AddRepoFailure.publicNeedsHttps);
      expect(env.server.requests, isEmpty);
      expect(await stored(), isEmpty);
    });

    test('bad URLs', () async {
      for (final input in ['', 'not a url', 'ftp://repo.lan/x', '/plugins']) {
        expect(
          failureOf(await env.repos.add(input)),
          AddRepoFailure.invalidUrl,
          reason: input,
        );
      }
      expect(
        failureOf(await env.repos.add('http://user:pw@repo.lan/plugins.json')),
        AddRepoFailure.invalidUrl,
      );
    });

    test('a refused range says which rule', () async {
      env.resolver.answers['bad.lan'] = [
        ['0.0.0.0'],
      ];
      final result = await env.repos.add('http://bad.lan/plugins.json');
      expect(result, isA<AddRepoFailed>());
      expect((result as AddRepoFailed).failure, AddRepoFailure.blockedAddress);
      expect(result.addressProblem, RepoAddressProblem.refusedAddress);
    });

    test('unknown host is a network error, 404 is not found', () async {
      expect(
        failureOf(await env.repos.add('http://gone.lan/plugins.json')),
        AddRepoFailure.network,
      );
      expect(
        failureOf(await env.repos.add('http://repo.lan:8080/missing.json')),
        AddRepoFailure.notFound,
      );
    });

    test('a body that is not a catalog is a bad format', () async {
      env.routes['/plugins.json'] = '{"hello": 1}'.codeUnits;
      expect(
        failureOf(await env.repos.add(catalogUrl)),
        AddRepoFailure.badFormat,
      );
      env.routes['/plugins.json'] = 'not json'.codeUnits;
      expect(
        failureOf(await env.repos.add(catalogUrl)),
        AddRepoFailure.badFormat,
      );
      expect(await stored(), isEmpty);
    });

    test('an empty catalog is a repo with no plugin', () async {
      env.serveCatalog([]);
      expect(
        ((await env.repos.add(catalogUrl)) as AddRepoAdded).pluginCount,
        0,
      );
    });
  });

  group('remove', () {
    test('keeps installed plugins and their repo address', () async {
      await env.repos.add(catalogUrl);
      env.routes['/demo.zip'] = pluginZip();
      final done = await env.repos.install(catalogUrl, 'demo');
      expect(done, isA<RepoPluginDone>());
      expect(await env.repos.remove(catalogUrl), isTrue);
      expect(await env.repos.remove(catalogUrl), isFalse);
      expect(await stored(), isEmpty);
      final records = await env.store.controller.watchRecords().first;
      expect(records.single.name, 'Demo');
      expect(records.single.repoUrl, catalogUrl);
      expect(records.single.isRemoved, isFalse);
    });
  });

  group('refreshAll', () {
    test('stores the new catalog', () async {
      await env.repos.add(catalogUrl);
      env.serveCatalog([entryJson(version: 9)]);
      final results = await env.repos.refreshAll();
      expect(results.single.error, isNull);
      final repo = (await stored()).single;
      expect(repo.catalog!.entries.single.version, 9);
      expect(repo.lastFetchedAt, isNotNull);
    });

    test('a failure keeps the old catalog and records the kind', () async {
      await env.repos.add(catalogUrl);
      env.failing['/plugins.json'] = 500;
      final results = await env.repos.refreshAll();
      expect(results.single.error?.kind, RepoFetchErrorKind.network);
      var repo = (await stored()).single;
      expect(repo.error?.kind, RepoFetchErrorKind.network);
      expect(repo.catalog!.entries, hasLength(2));

      env.failing.clear();
      env.routes['/plugins.json'] = 'garbage'.codeUnits;
      await env.repos.refreshAll();
      repo = (await stored()).single;
      expect(repo.error?.kind, RepoFetchErrorKind.invalidCatalog);
      expect(repo.catalog!.entries, hasLength(2));

      env.serveCatalog([entryJson()]);
      await env.repos.refreshAll();
      repo = (await stored()).single;
      expect(repo.error, isNull);
      expect(repo.catalog!.entries, hasLength(1));
    });

    test('a refused address is kept with its reason', () async {
      await env.repos.add(catalogUrl);
      env.resolver.answers['repo.lan'] = [
        ['0.0.0.0'],
      ];
      await env.repos.refreshAll();
      final error = (await stored()).single.error!;
      expect(error.kind, RepoFetchErrorKind.blockedAddress);
      expect(error.reason, RepoAddressProblem.refusedAddress);
    });

    test('fetches at most four at once and shares a running refresh', () async {
      for (var i = 0; i < 7; i++) {
        env.routes['/r$i.json'] = catalogJson([
          entryJson(),
        ], name: 'R$i').codeUnits;
        await env.store.db.addLyricsPluginRepo(
          'http://repo.lan:8080/r$i.json',
          name: 'R$i',
          now: i,
        );
      }
      var active = 0;
      var peak = 0;
      env.server.handler = (request) async {
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(const Duration(milliseconds: 80));
        request.response.add(env.routes[request.uri.path] ?? const []);
        await request.response.close();
        active--;
      };
      final first = env.repos.refreshAll();
      final second = env.repos.refreshAll();
      expect(identical(first, second), isTrue);
      final results = await first;
      expect(results, hasLength(7));
      expect(results.every((r) => r.error == null), isTrue);
      expect(peak, 4);
      expect(env.server.requests, hasLength(7));
      // A finished refresh is not shared with the next call.
      expect(identical(await env.repos.refreshAll(), results), isFalse);
    });
  });
}
