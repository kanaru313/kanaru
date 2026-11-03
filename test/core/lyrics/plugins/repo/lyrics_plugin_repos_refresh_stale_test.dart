import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_controller.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_http.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_refresh_runner.dart';

import '../store/store_test_env.dart';
import 'repo_controller_env.dart';

void main() {
  late RepoEnv env;
  var now = DateTime.utc(2026, 11, 3, 10);

  setUp(() async {
    now = DateTime.utc(2026, 11, 3, 10);
    env = await RepoEnv.create(clock: () => now);
    env.serveCatalog([entryJson()]);
  });
  tearDown(() => env.dispose());

  void advance(Duration d) => now = now.add(d);

  group('refreshStale', () {
    test('fetches a repository that was never fetched', () async {
      await env.store.db.addLyricsPluginRepo(
        catalogUrl,
        name: 'Official',
        now: now.millisecondsSinceEpoch,
      );
      final results = await env.repos.refreshStale();
      expect(results.map((r) => r.url), [catalogUrl]);
      expect(env.server.requests, hasLength(1));
    });

    test('skips a repository fetched less than an hour ago', () async {
      await env.repos.add(catalogUrl);
      env.server.requests.clear();
      advance(const Duration(minutes: 59));
      expect(await env.repos.refreshStale(), isEmpty);
      expect(env.server.requests, isEmpty);
      final repos = await env.repos.watchRepos().first;
      expect(repos.single.catalog, isNotNull);
    });

    test('fetches at exactly an hour', () async {
      await env.repos.add(catalogUrl);
      env.server.requests.clear();
      advance(const Duration(minutes: 60));
      expect(await env.repos.refreshStale(), hasLength(1));
      expect(env.server.requests, hasLength(1));
    });

    test('fetches again after a failed fetch and clears the error', () async {
      await env.repos.add(catalogUrl);
      env.failing['/plugins.json'] = 500;
      await env.repos.refreshAll();
      expect((await env.repos.watchRepos().first).single.error, isNotNull);
      env.failing.clear();
      env.server.requests.clear();
      advance(const Duration(minutes: 1));
      expect(await env.repos.refreshStale(), hasLength(1));
      expect((await env.repos.watchRepos().first).single.error, isNull);
    });

    test(
      'a failure persisted in the database is retried after a restart',
      () async {
        await env.repos.add(catalogUrl);
        env.failing['/plugins.json'] = 500;
        await env.repos.refreshAll();
        env.failing.clear();
        env.server.requests.clear();
        advance(const Duration(minutes: 1));
        final restarted = LyricsPluginReposController(
          db: env.store.db,
          plugins: env.store.controller,
          reader: PluginPackageReader(FakeRuntime()),
          http: RepoHttp(resolver: env.resolver.call, dialer: env.dialer.call),
          clock: () => now,
        );
        addTearDown(restarted.dispose);
        expect(await restarted.refreshStale(), hasLength(1));
        expect(env.server.requests, hasLength(1));
      },
    );

    test('fetches a repository dated in the future', () async {
      await env.repos.add(catalogUrl);
      env.server.requests.clear();
      advance(const Duration(days: -1));
      expect(await env.repos.refreshStale(), hasLength(1));
    });

    test('fetches a repository whose stored catalog is unreadable', () async {
      await env.repos.add(catalogUrl);
      await env.store.db.saveLyricsPluginRepoFetch(
        catalogUrl,
        catalog: '{}',
        now: now.millisecondsSinceEpoch,
      );
      env.server.requests.clear();
      expect(await env.repos.refreshStale(), hasLength(1));
    });

    test('refreshAll still fetches a fresh repository', () async {
      await env.repos.add(catalogUrl);
      env.server.requests.clear();
      expect(await env.repos.refreshAll(), hasLength(1));
      expect(env.server.requests, hasLength(1));
    });

    test('shares a running refreshAll', () async {
      await env.repos.add(catalogUrl);
      env.server.requests.clear();
      final gate = Completer<void>();
      env.server.handler = (request) async {
        await gate.future;
        request.response.add(utf8.encode(catalogJson([entryJson()])));
        await request.response.close();
      };
      final all = env.repos.refreshAll();
      final stale = env.repos.refreshStale();
      gate.complete();
      expect(await stale, same(await all));
      expect(env.server.requests, hasLength(1));
    });

    test('shares the fetch of a repository being refreshed', () async {
      await env.store.db.addLyricsPluginRepo(
        catalogUrl,
        name: 'Official',
        now: now.millisecondsSinceEpoch,
      );
      final gate = Completer<void>();
      env.server.handler = (request) async {
        await gate.future;
        request.response.add(utf8.encode(catalogJson([entryJson()])));
        await request.response.close();
      };
      final one = env.repos.refresh(catalogUrl);
      for (var i = 0; i < 200 && env.server.requests.isEmpty; i++) {
        await pumpEventQueue();
      }
      final stale = env.repos.refreshStale();
      // A read issued after refreshStale's listing finishes after it, so
      // refreshStale has joined the running fetch before the gate opens.
      await env.store.db.watchLyricsPluginRepos().first;
      await pumpEventQueue();
      gate.complete();
      expect(await stale, hasLength(1));
      await one;
      expect(env.server.requests, hasLength(1));
    });
  });

  group('repoNeedsRefresh', () {
    const max = Duration(hours: 1);
    bool needs({
      int? last = 1000,
      bool failed = false,
      bool catalog = true,
      int now = 1000,
    }) => repoNeedsRefresh(
      lastFetchedAt: last,
      failed: failed,
      hasCatalog: catalog,
      now: now,
      maxAge: max,
    );

    test('decides from the inputs', () {
      expect(needs(last: null), isTrue);
      expect(needs(failed: true), isTrue);
      expect(needs(catalog: false), isTrue);
      expect(needs(), isFalse);
      expect(needs(now: 1000 + max.inMilliseconds - 1), isFalse);
      expect(needs(now: 1000 + max.inMilliseconds), isTrue);
      expect(needs(now: 999), isTrue);
    });
  });
}
