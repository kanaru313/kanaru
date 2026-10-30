@Tags(['native'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';

import '../core/lyrics_translation/loopback_server.dart';
import 'fake_lrclib.dart';
import 'lrclib_comparison_support.dart';
import 'native_plugin_env.dart';
import 'plugin_fixture_zip.dart';

// The sample LRCLIB plugin (test/fixtures/lyrics_plugins/lrclib) and the Dart
// LRCLIB provider answer the same fake LRCLIB. The whole chain is real: zip,
// install with the native syntax check, package loader, native runtime,
// fetch bridge, LyricsHttp (strict hosts), host ranking and the database.
// Run `cargo build --manifest-path rust/Cargo.toml` first; without the
// library every test here is reported skipped with that hint.
void main() {
  late LoopbackServer server;
  late NativePluginEnv env;
  late LyricsProviderRegistration dart;
  late LyricsProviderRegistration plugin;

  setUpAll(initNativeLibrary);

  setUp(() async {
    server = await LoopbackServer.start(lrclibReply);
    addTearDown(server.close);
    dart = LyricsProviderRegistration(LrclibProvider());
    if (nativeSkipReason != null) return;
    env = await NativePluginEnv.create();
    addTearDown(env.dispose);
    final record = await env.install(zipFixtureFolder('lrclib'));
    plugin = LyricsProviderRegistration(env.providerFor(record));
  });

  group('automatic lookup', () {
    for (final song in lrclibSongs) {
      nativeTest(
        '${song.name}: same stored row as the Dart provider',
        () async {
          final fromDart = await autoLookup(dart, song, server);
          final fromPlugin = await autoLookup(
            plugin,
            song,
            server,
            database: env.db,
          );
          expect(fromDart.rows, hasLength(1));
          expect(
            fromPlugin.rows.map(withoutPlain),
            fromDart.rows.map(withoutPlain),
          );
          if (!song.bothTexts) {
            expect(fromPlugin.rows, fromDart.rows);
          }
        },
      );
    }

    nativeTest('rows hold what the fake LRCLIB had', () async {
      // Guards the comparison above against two empty answers.
      final synced = (await autoLookup(
        dart,
        lrclibSongs[0],
        server,
      )).rows.single;
      expect(synced.remoteId, '101');
      expect(synced.synced, startsWith('[00:01.00] first line'));
      final instrumental = (await autoLookup(
        dart,
        lrclibSongs[2],
        server,
      )).rows.single;
      expect(instrumental.instrumental, isTrue);
      expect(
        (await autoLookup(dart, lrclibSongs[3], server)).rows.single.status,
        'not_found',
      );
    });

    nativeTest(
      'zero duration and multi-artist tags are really exercised',
      () async {
        final zero = lrclibSongs.firstWhere((s) => s.name == 'zero');
        final multi = lrclibSongs.firstWhere((s) => s.name == 'multi');
        for (final r in [dart, plugin]) {
          final db = r == plugin ? env.db : null;
          // A record without a duration cannot pass the match gate, so the
          // lookup is a miss for both.
          final rows = (await autoLookup(r, zero, server, database: db)).rows;
          expect(rows.single.status, 'not_found');
          // The search lists the 0 s record without a duration, and never
          // the one over a day.
          final ranked = (await manualSearch(
            r,
            zero,
            server,
            database: db,
          )).ranked;
          expect(
            [for (final e in ranked) (e.remoteId, e.durationMs)],
            [('401', null)],
          );
        }
        // A tag with two artists: no artist_name in the plugin's search.
        await autoLookup(plugin, multi, server, database: env.db);
        expect(server.requests.single.uri.queryParameters, {
          'track_name': 'Synced Song',
        });
      },
    );

    nativeTest('DIFFERENCE: a record with synced and plain text keeps only the '
        'synced text through a plugin', () async {
      // A plugin result carries one text (`lyrics` of search.js, or `data`
      // of lyrics.js), while LRCLIB's record has both and the Dart provider
      // stores both.
      final fromDart = await autoLookup(dart, lrclibSongs[0], server);
      final fromPlugin = await autoLookup(
        plugin,
        lrclibSongs[0],
        server,
        database: env.db,
      );
      expect(fromDart.rows.single.plain, 'first line\nsecond line');
      expect(fromPlugin.rows.single.plain, isNull);
    });

    nativeTest(
      'DIFFERENCE: the plugin has no exact lookup, so it sends a search '
      'where the Dart provider sends /api/get first',
      () async {
        Future<List<String>> paths(
          LyricsProviderRegistration r,
          LrclibSong s,
        ) async => (await autoLookup(
          r,
          s,
          server,
          database: r == plugin ? env.db : null,
        )).paths;

        expect(await paths(dart, lrclibSongs[0]), ['/api/get']);
        expect(await paths(plugin, lrclibSongs[0]), ['/api/search']);
        // Plain-only exact hit: the Dart provider also searches for a synced
        // twin.
        expect(await paths(dart, lrclibSongs[1]), ['/api/get', '/api/search']);
        expect(await paths(plugin, lrclibSongs[1]), ['/api/search']);
        // The record of a search for an instrumental song has no text, so
        // the host asks lyrics.js for it.
        expect(await paths(dart, lrclibSongs[2]), ['/api/get']);
        expect(await paths(plugin, lrclibSongs[2]), [
          '/api/search',
          '/api/get/301',
        ]);
        expect(await paths(dart, lrclibSongs[3]), ['/api/get', '/api/search']);
        expect(await paths(plugin, lrclibSongs[3]), ['/api/search']);
      },
    );
  });

  group('manual search', () {
    for (final song in lrclibSongs) {
      nativeTest(
        '${song.name}: same ranked order as the Dart provider',
        () async {
          final fromDart = await manualSearch(dart, song, server);
          final fromPlugin = await manualSearch(
            plugin,
            song,
            server,
            database: env.db,
          );
          expect(fromPlugin.ranked, fromDart.ranked);
          expect(fromPlugin.selectedId, fromDart.selectedId);
          final (dartSynced, dartPlain, dartInstrumental) =
              fromDart.selectedBody ?? (null, null, false);
          final (synced, plain, instrumental) =
              fromPlugin.selectedBody ?? (null, null, false);
          expect((synced, instrumental), (dartSynced, dartInstrumental));
          if (!song.bothTexts) expect(plain, dartPlain);
        },
      );
    }

    nativeTest('the ranked list is not empty for a song LRCLIB has', () async {
      final ranked = (await manualSearch(dart, lrclibSongs[0], server)).ranked;
      expect(ranked.map((r) => r.remoteId), ['101', '103', '102']);
      expect(ranked.first.goodMatch, isTrue);
    });
  });
}
