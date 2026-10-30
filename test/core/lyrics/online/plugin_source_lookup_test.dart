import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_search_controller.dart';
import 'package:kanaru/core/lyrics/online/lyrics_source_names.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_lookups.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_streams.dart';
import 'package:kanaru/core/lyrics/online/playing_lyrics_status.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_provider.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_log_paths.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_registry.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime_provider.dart';

import '../plugins/plugin_provider_env.dart';
import '../plugins/store/store_test_env.dart' show testPackage, testRepoSource;
import 'fake_lyrics_provider.dart';
import 'lookup_test_harness.dart';
import 'status_test_rig.dart';

const _searchHit =
    '[{"id":"r1","title":"Song","artist":"Artist","durationMs":200000}]';
const _inlineHit =
    '[{"id":"r1","title":"Song","artist":"Artist",'
    '"durationMs":200000,"lyrics":"[00:01.00] late"}]';
const _lyricsHit = '{"data":"[00:01.00] words","type":"lrc"}';

void main() {
  late PluginProviderEnv env;
  late LyricsPluginRecord record;

  setUp(() async {
    env = await PluginProviderEnv.create();
    addTearDown(env.dispose);
    record = await env.install();
  });

  Future<List<OnlineLyricsRow>> rows() =>
      env.db.watchOnlineLyrics(fakeTarget.cacheKey).first;

  List<Override> pluginOverrides() => [
    lyricsPluginDataDirectoryProvider.overrideWithValue(env.store.dataDir.path),
    pluginRuntimeProvider.overrideWithValue(env.runtime),
    pluginRunRegistryProvider.overrideWithValue(env.store.runs),
    lyricsPluginsControllerProvider.overrideWithValue(env.controller),
  ];

  Future<void> saveFound(String providerId) => env.db.saveOnlineLyrics(
    OnlineLyricsCompanion.insert(
      cacheKey: fakeTarget.cacheKey,
      providerId: providerId,
      status: OnlineLyricsStatus.found.value,
      remoteId: const Value('r1'),
      syncedText: const Value('[00:01.00] saved'),
      fetchedAt: DateTime.utc(2026, 10, 29, 12).millisecondsSinceEpoch,
    ),
  );

  group('a plugin in a lookup', () {
    test('body-less results are fetched and stored under its id', () async {
      env.runtime
        ..onSearch(okResult(_searchHit))
        ..onLyrics(okResult(_lyricsHit));
      final h = await createHarness([
        LyricsProviderRegistration(env.providerFor(record)),
      ], database: env.db);

      await h.lookups.start(fakeTarget, auto: true);

      final stored = await rows();
      expect(stored.single.providerId, record.installId);
      expect(stored.single.status, OnlineLyricsStatus.found.value);
      expect(stored.single.remoteId, 'r1');
      expect(stored.single.syncedText, '[00:01.00] words');
      expect(env.runtime.requests.map((r) => r.entry), [
        'search.js',
        'lyrics.js',
      ]);
    });

    test('a plugin with no row is asked although LRCLIB missed', () async {
      final lrclib = FakeLyricsProvider();
      env.runtime
        ..onSearch(okResult(_searchHit))
        ..onLyrics(okResult(_lyricsHit));
      final h = await createHarness([
        LyricsProviderRegistration(lrclib),
        LyricsProviderRegistration(env.providerFor(record)),
      ], database: env.db);
      await h.db.saveOnlineLyrics(
        OnlineLyricsCompanion.insert(
          cacheKey: fakeTarget.cacheKey,
          providerId: 'fake',
          status: OnlineLyricsStatus.notFound.value,
          fetchedAt: h.now.millisecondsSinceEpoch,
        ),
      );

      await h.lookups.start(fakeTarget, auto: true);

      expect(lrclib.lookupCalls + lrclib.searchCalls, 0);
      expect(env.runtime.requests, isNotEmpty);
      expect(
        (await rows()).map((r) => r.providerId),
        contains(record.installId),
      );
    });

    test(
      'a busy runtime leaves the source unasked: no row, no pause',
      () async {
        env.runtime.onSearch(
          const PluginRunResult(status: PluginRunStatus.busy),
        );
        final h = await createHarness([
          LyricsProviderRegistration(env.providerFor(record)),
        ], database: env.db);

        await h.lookups.start(fakeTarget, auto: true);

        expect(await rows(), isEmpty);
        expect(h.backoff.isPaused(record.installId), isFalse);
        expect(h.lookups.leftSourceUnasked(fakeTarget.cacheKey), isTrue);
      },
    );

    test('an uninstall during the lookup stops it quietly', () async {
      final started = Completer<void>();
      env.runtime.handlers['search.js'] = cancelledWhenStopped(started);
      final h = await createHarness([
        LyricsProviderRegistration(env.providerFor(record)),
      ], database: env.db);

      final done = h.lookups.start(fakeTarget, auto: true);
      await started.future;
      await env.controller.uninstall(record.installId);
      await done;

      expect(await rows(), isEmpty);
      expect(h.container.read(onlineLyricsLookupsProvider), isEmpty);
      expect(h.backoff.isPaused(record.installId), isFalse);
    });

    test('an answer that outlives the uninstall is dropped', () async {
      final started = Completer<void>();
      final release = Completer<void>();
      env.runtime.handlers['search.js'] = (_, _, _) async {
        started.complete();
        await release.future;
        return okResult(_inlineHit);
      };
      final h = await createHarness([
        LyricsProviderRegistration(env.providerFor(record)),
      ], database: env.db);

      final done = h.lookups.start(fakeTarget, auto: true);
      await started.future;
      await env.controller.uninstall(record.installId);
      release.complete();
      await done;

      expect(await rows(), isEmpty);
      expect(h.container.read(onlineLyricsLookupsProvider), isEmpty);
    });

    test('a record removed before the row is saved is not "found"', () async {
      // Removed behind the registry's back, so the run is not cancelled and
      // finishes with lyrics; the database refuses the row.
      env.runtime.handlers['search.js'] = (_, _, _) async {
        await env.db.customStatement(
          'UPDATE lyrics_plugins SET removed_at = 1 WHERE install_id = ?',
          [record.installId],
        );
        return okResult(_inlineHit);
      };
      final h = await createHarness([
        LyricsProviderRegistration(env.providerFor(record)),
      ], database: env.db);

      await h.lookups.start(fakeTarget, auto: true);

      expect(await rows(), isEmpty);
      expect(h.lookups.leftSourceUnasked(fakeTarget.cacheKey), isTrue);
      expect(h.container.read(onlineLyricsLookupsProvider), isEmpty);
      expect(h.backoff.isPaused(record.installId), isFalse);
    });
  });

  group('a plugin stopped by an update or uninstall', () {
    LyricsSearchController search(LyricsHarness h) =>
        h.container.read(lyricsSearchControllerProvider(fakeTarget).notifier);
    LyricsSearchState searchState(LyricsHarness h) =>
        h.container.read(lyricsSearchControllerProvider(fakeTarget));

    Future<LyricsHarness> harnessFor(LyricsPluginRecord r) async {
      final h = await createHarness([
        LyricsProviderRegistration(env.providerFor(r)),
      ], database: env.db);
      h.container.listen(lyricsSearchControllerProvider(fakeTarget), (_, _) {});
      return h;
    }

    test('the picker search row finishes, not stuck searching', () async {
      final repo = await env.install(name: 'Repo', source: testRepoSource);
      final started = Completer<void>();
      env.runtime.handlers['search.js'] = cancelledWhenStopped(started);
      final h = await harnessFor(repo);

      final done = search(h).search('x');
      await started.future;
      await env.controller.updatePackage(
        repo.installId,
        testPackage(name: 'Repo', version: 2),
      );
      await done;

      final row = searchState(h).byProvider[repo.installId]!;
      expect(row.phase, ProviderSearchPhase.done);
      expect(searchState(h).searching, isFalse);
    });

    test('the body fetch goes back to not fetched', () async {
      final repo = await env.install(name: 'Repo', source: testRepoSource);
      env.runtime.onSearch(okResult(_searchHit));
      final started = Completer<void>();
      env.runtime.handlers['lyrics.js'] = cancelledWhenStopped(started);
      final h = await harnessFor(repo);

      final done = search(h).search('x');
      await started.future;
      await env.controller.updatePackage(
        repo.installId,
        testPackage(name: 'Repo', version: 2),
      );
      await done;

      expect(searchState(h).bodyFetches, isEmpty);
      expect(searchState(h).searching, isFalse);
    });

    test('an automatic lookup still asks LRCLIB afterwards', () async {
      final lrclib = FakeLyricsProvider();
      final started = Completer<void>();
      env.runtime.handlers['search.js'] = cancelledWhenStopped(started);
      final h = await createHarness([
        LyricsProviderRegistration(env.providerFor(record)),
        LyricsProviderRegistration(lrclib),
      ], database: env.db);

      final done = h.lookups.start(fakeTarget, auto: true);
      await started.future;
      await env.controller.uninstall(record.installId);
      await done;

      expect(lrclib.lookupCalls, 1);
      expect(h.backoff.isPaused(record.installId), isFalse);
    });
  });

  group('stored rows of plugins', () {
    test('a disabled plugin is not run but its found row shows', () async {
      await saveFound(record.installId);
      await env.controller.setEnabled(record.installId, false);
      final h = await createHarness(
        null,
        database: env.db,
        forceSourcesLoaded: false,
        overrides: pluginOverrides(),
      );
      final cache = onlineLyricsCacheProvider(fakeTarget.cacheKey);
      h.container.listen(cache, (_, _) {});
      h.container.listen(lyricsSourceNamesProvider, (_, _) {});

      final entries = await h.container.read(cache.future);
      expect(entries.map((e) => e.providerId), [record.installId]);

      await h.lookups.start(fakeTarget, auto: true);
      expect(env.runtime.requests, isEmpty);
    });

    test('a removed plugin keeps its row, named as removed', () async {
      await saveFound(record.installId);
      await env.controller.uninstall(record.installId);
      final h = await createHarness(
        null,
        database: env.db,
        forceSourcesLoaded: false,
        overrides: pluginOverrides(),
      );
      final cache = onlineLyricsCacheProvider(fakeTarget.cacheKey);
      h.container.listen(cache, (_, _) {});
      h.container.listen(lyricsSourceNamesProvider, (_, _) {});

      final entries = await h.container.read(cache.future);

      expect(entries.map((e) => e.providerId), [record.installId]);
      final names = h.container.read(lyricsSourceNamesProvider);
      expect(names[record.installId]!.removed, isTrue);
      expect(names[record.installId]!.displayName, 'Demo');
    });
  });

  test('a disabled LRCLIB keeps its found row listed', () async {
    await saveFound('lrclib');
    await env.db.setLyricsSourceEnabled('lrclib', false);
    final h = await createHarness(
      null,
      database: env.db,
      forceSourcesLoaded: false,
      overrides: pluginOverrides(),
    );
    final cache = onlineLyricsCacheProvider(fakeTarget.cacheKey);
    h.container.listen(cache, (_, _) {});
    h.container.listen(lyricsSourceNamesProvider, (_, _) {});

    final entries = await h.container.read(cache.future);

    expect(entries.map((e) => e.providerId), ['lrclib']);
    expect(
      h.container.read(lyricsSourceNamesProvider)['lrclib']!.removed,
      false,
    );
  });

  group('cold start', () {
    test('a cached plugin row is shown with no request at all', () async {
      await saveFound(record.installId);
      final rig = await createStatusRig(
        realSources: true,
        database: env.db,
        overrides: pluginOverrides(),
      );
      rig.watch();
      await rig.play([fakeSong('/music/song.flac')]);
      await rig.until((() => rig.status is LyricsFound));

      expect(rig.client.opened, 0);
      expect(env.runtime.requests, isEmpty);
    });
  });
}
