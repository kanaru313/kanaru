@Tags(['native'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';

import '../core/lyrics_translation/loopback_server.dart';
import 'fake_lrclib.dart';
import 'lrclib_comparison_support.dart';
import 'native_plugin_env.dart';
import 'plugin_fixture_zip.dart';

// What the sample LRCLIB plugin does not copy from the Dart provider, run on
// the same fake LRCLIB. Each test records the observed behavior; none hides a
// difference.
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

  // Calls a provider directly with the strict host rules, bypassing the
  // host's own pre-checks, and returns what it sent and found.
  Future<(List<Map<String, String>>, List<(String, String, String)>)> search(
    LyricsProviderRegistration r,
    LyricsQuery query,
  ) async {
    server.requests.clear();
    final client = LrclibRoutingClient(server);
    final found = await r.provider.search(query, LyricsHttp(r, client));
    return (
      [for (final q in server.requests) q.uri.queryParameters],
      [for (final c in found) (c.remoteId, c.title, c.artist)],
    );
  }

  nativeTest(
    'DIFFERENCE: an "Unknown Artist" tag is sent as artist_name by the '
    'plugin only (the host never sends such a search)',
    () async {
      const query = LyricsQuery(title: 'Plain Song', artist: 'Unknown Artist');
      final (dartSent, dartFound) = await search(dart, query);
      final (pluginSent, pluginFound) = await search(plugin, query);
      // The Dart provider drops the placeholder; search.js sends it, so
      // LRCLIB finds nothing for it.
      expect(dartSent, [
        {'track_name': 'Plain Song'},
      ]);
      expect(pluginSent, [
        {'track_name': 'Plain Song', 'artist_name': 'Unknown Artist'},
      ]);
      expect(dartFound.map((c) => c.$1), ['201']);
      expect(pluginFound, isEmpty);

      // The host does not reach this: a placeholder artist is not
      // auto-searchable, and the manual search sends the typed text only. So
      // no stored row or ranking differs.
      const song = LrclibSong('unknown', 'Plain Song', 'Unknown Artist', 180);
      expect(song.target.isAutoSearchable, isFalse);
      expect(
        (await autoLookup(plugin, song, server, database: env.db)).paths,
        isEmpty,
      );
      final manualDart = await manualSearch(dart, song, server);
      final manualPlugin = await manualSearch(
        plugin,
        song,
        server,
        database: env.db,
      );
      expect(manualPlugin.ranked, manualDart.ranked);
    },
  );

  nativeTest(
    'DIFFERENCE: search.js does not clean titles; the host and the Dart '
    'provider give the same result',
    () async {
      const query = LyricsQuery(text: 'Messy Song');
      final (_, dartFound) = await search(dart, query);
      final (_, pluginFound) = await search(plugin, query);
      // The Dart provider cleans the title in the record; the plugin passes
      // it on as LRCLIB sent it.
      expect(dartFound.single.$2, 'Messy Song');
      expect(pluginFound.single.$2, '  Messy\u0001 Song  ');

      // The host checks plugin output again before ranking and showing it.
      const song = LrclibSong('messy', 'Messy Song', 'Messy Artist', 160);
      final manualDart = await manualSearch(dart, song, server);
      final manualPlugin = await manualSearch(
        plugin,
        song,
        server,
        database: env.db,
      );
      expect([for (final e in manualDart.ranked) e.title], ['Messy Song']);
      expect(manualPlugin.ranked, manualDart.ranked);
    },
  );
}
