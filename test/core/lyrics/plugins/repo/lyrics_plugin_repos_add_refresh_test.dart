import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_controller.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_catalog.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';

import 'repo_controller_env.dart';

const otherUrl = 'http://repo.lan:8080/other.json';

AddRepoFailure? failureOf(AddRepoResult r) =>
    r is AddRepoFailed ? r.failure : null;

void main() {
  late RepoEnv env;

  setUp(() async {
    env = await RepoEnv.create();
    env.serveCatalog([entryJson()]);
    env.routes['/other.json'] = utf8.encode(
      catalogJson([entryJson()], name: 'Other'),
    );
  });
  tearDown(() => env.dispose());

  Future<List<PluginRepo>> stored() => env.repos.watchRepos().first;

  /// Holds the answer for `/plugins.json` until [gate] completes.
  void holdCatalog(Completer<void> gate) {
    env.server.handler = (request) async {
      if (request.uri.path == '/plugins.json') await gate.future;
      final body = env.routes[request.uri.path];
      if (body == null) {
        request.response.statusCode = 404;
      } else {
        request.response.add(body);
      }
      await request.response.close();
    };
  }

  Future<void> waitForRequest() async {
    for (var i = 0; i < 200 && env.server.requests.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('add cleans up after itself', () {
    test('a failing catalog write removes the row again', () async {
      await env.store.db.customStatement(
        'CREATE TRIGGER fail_write BEFORE UPDATE ON lyrics_plugin_repos '
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      expect(
        failureOf(await env.repos.add(catalogUrl)),
        AddRepoFailure.storage,
      );
      expect(await stored(), isEmpty);
    });

    test(
      'a catalog that grows over the cap once stored is bad format',
      () async {
        // The stored form has absolute addresses, so it is a little larger than
        // what was fetched. Fill the fetched text up to just under the cap.
        List<Map<String, Object?>> entries(int pathLength) => [
          for (var i = 0; i < maxCatalogEntries; i++)
            entryJson(
              slug: 's$i',
              name: 'Plugin $i',
              path: '${'p' * pathLength}.zip',
              hosts: [
                for (var h = 0; h < 20; h++) 'h$h-${'x' * 30}.example.com',
              ],
              author: 'a' * 40,
            ),
        ];
        int rawSize(int pathLength) =>
            utf8.encode(catalogJson(entries(pathLength))).length;
        final base = rawSize(1);
        final pathLength =
            (lyricsPluginCatalogMaxBytes - 6000 - base) ~/ maxCatalogEntries;
        expect(pathLength, greaterThan(1));
        expect(pathLength, lessThan(2000));
        final raw = utf8.encode(catalogJson(entries(pathLength)));
        expect(raw.length, lessThanOrEqualTo(lyricsPluginCatalogMaxBytes));
        env.routes['/plugins.json'] = raw;

        expect(
          failureOf(await env.repos.add(catalogUrl)),
          AddRepoFailure.badFormat,
        );
        expect(await stored(), isEmpty, reason: 'no half-added row');
      },
    );
  });

  group('the address is fetched as typed', () {
    test('a trailing slash is kept in the fetched address', () async {
      env.routes['/plugins.json/'] = utf8.encode(catalogJson([entryJson()]));
      final added = await env.repos.add(
        'http://repo.lan:8080/plugins.json/',
      ) as AddRepoAdded;
      expect(added.url, 'http://repo.lan:8080/plugins.json/');
      expect(env.server.requests.single.uri.path, '/plugins.json/');
      // Another spelling of the same address is the same repository.
      expect(
        failureOf(await env.repos.add('HTTP://REPO.LAN:8080/plugins.json/')),
        AddRepoFailure.duplicate,
      );
    });
  });

  group('add that overlaps or loses its row', () {
    test('two adds of one address share one run', () async {
      final gate = Completer<void>();
      holdCatalog(gate);
      final a = env.repos.add(catalogUrl);
      final b = env.repos.add(catalogUrl);
      expect(identical(a, b), isTrue);
      await waitForRequest();
      gate.complete();
      expect(await a, isA<AddRepoAdded>());
      expect(await stored(), hasLength(1));
      expect(env.server.requests.length, 1);
      // The entry is gone: the same address is now a duplicate.
      expect(
        failureOf(await env.repos.add(catalogUrl)),
        AddRepoFailure.duplicate,
      );
    });

    test('a row removed during the add is storage and not stored', () async {
      await env.store.db.customStatement(
        'CREATE TRIGGER drop_row AFTER INSERT ON lyrics_plugin_repos '
        'BEGIN DELETE FROM lyrics_plugin_repos WHERE url = NEW.url; END',
      );
      final result = await env.repos.add(catalogUrl);
      expect(failureOf(result), AddRepoFailure.storage);
      expect(await stored(), isEmpty);
    });
  });

  group('refresh of one repository', () {
    test('fetches and stores one repo only', () async {
      await env.repos.add(catalogUrl);
      await env.repos.add(otherUrl);
      env.server.requests.clear();
      final result = await env.repos.refresh(catalogUrl);
      expect(result?.url, catalogUrl);
      expect(result?.error, isNull);
      expect(env.server.requests.map((r) => r.uri.path), ['/plugins.json']);
    });

    test('shares the fetch of a refresh all that is running', () async {
      await env.repos.add(catalogUrl);
      env.server.requests.clear();
      final gate = Completer<void>();
      holdCatalog(gate);
      final all = env.repos.refreshAll();
      await waitForRequest();
      final one = env.repos.refresh(catalogUrl);
      gate.complete();
      expect((await one)?.url, catalogUrl);
      expect(await all, hasLength(1));
      expect(env.server.requests.length, 1);
    });

    test('is null for an unknown repo and one being added', () async {
      expect(await env.repos.refresh(otherUrl), isNull);
      expect(env.server.requests, isEmpty);
      final gate = Completer<void>();
      holdCatalog(gate);
      final add = env.repos.add(catalogUrl);
      await waitForRequest();
      expect(await env.repos.refresh(catalogUrl), isNull);
      gate.complete();
      await add;
    });

    test('reports a failed fetch and keeps the old catalog', () async {
      await env.repos.add(catalogUrl);
      env.routes.remove('/plugins.json');
      final result = await env.repos.refresh(catalogUrl);
      expect(result?.error?.kind, RepoFetchErrorKind.notFound);
      expect((await stored()).single.catalog, isNotNull);
    });
  });

  group('add and remove while a refresh runs', () {
    test('a repo removed meanwhile does not come back', () async {
      await env.repos.add(catalogUrl);
      env.server.requests.clear();
      final gate = Completer<void>();
      holdCatalog(gate);

      final refresh = env.repos.refreshAll();
      await waitForRequest();
      expect(await env.repos.remove(catalogUrl), isTrue);
      gate.complete();

      expect(await refresh, isEmpty, reason: 'nothing to report for it');
      expect(await stored(), isEmpty);
    });

    test('a repo added meanwhile is left alone by that refresh', () async {
      await env.repos.add(catalogUrl);
      env.server.requests.clear();
      final gate = Completer<void>();
      holdCatalog(gate);

      final refresh = env.repos.refreshAll();
      await waitForRequest();
      expect(await env.repos.add(otherUrl), isA<AddRepoAdded>());
      gate.complete();

      final results = await refresh;
      expect(results.map((r) => r.url), [catalogUrl]);
      final repos = await stored();
      expect(repos, hasLength(2));
      expect(repos.every((r) => r.error == null), isTrue);
      expect(repos.every((r) => r.catalog != null), isTrue);
    });

    test(
      'a failed refresh of one repo keeps its old catalog and kind',
      () async {
        await env.repos.add(catalogUrl);
        env.failing['/plugins.json'] = 500;
        final results = await env.repos.refreshAll();
        expect(results.single.error!.kind, RepoFetchErrorKind.network);
        final repo = (await stored()).single;
        expect(repo.catalog, isNotNull);
        expect(repo.kind, RepoAddressKind.local);
      },
    );
  });
}
