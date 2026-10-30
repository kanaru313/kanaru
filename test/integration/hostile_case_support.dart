import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/online_lyrics_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_target.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_lookups.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugins_controller.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_log_paths.dart';
import 'package:logging/logging.dart';

import '../core/lyrics/online/lookup_test_harness.dart';
import '../core/lyrics_translation/loopback_server.dart';
import 'fake_lrclib.dart';
import 'native_plugin_env.dart';
import 'plugin_fixture_zip.dart';

/// What the host must show for one hostile plugin: the failure, and what the
/// plugin's log file holds.
class HostileCase {
  const HostileCase(
    this.folder,
    this.kind, {
    this.console,
    this.requests = const [],
    this.message,
    this.appLogHost,
    this.configValue,
  });

  /// Folder under `test/fixtures/lyrics_plugins/hostile`.
  final String folder;

  /// The `LyricsFetchKind` of the lookup's failure.
  final LyricsFetchKind kind;

  /// The exact console lines of the run, or `null` to skip the check.
  final List<String>? console;

  /// The requests the run logged, as `host path status`.
  final List<String> requests;

  /// What the logged message must contain, if anything.
  final String? message;

  /// The host the app log line names (a blocked address), if any.
  final String? appLogHost;

  /// A value for the plugin's `token` config. The script prints it and puts
  /// it in an address; it must be in no log, only `***`.
  final String? configValue;
}

/// The song every hostile case is asked for. Its title and artist are made
/// to be found in a log by a search.
const _title = 'Hostile Song Title';
const _artist = 'Hostile Artist Name';

final _target = LyricsTarget.fromFields(
  uri: '/music/hostile.flac',
  title: _title,
  artist: _artist,
  album: 'Album',
  duration: const Duration(seconds: 200),
);

/// Installs the fixture, runs the automatic lookup and checks the contract
/// of a failed run (see [HostileCase]): the kind, nothing stored as "not
/// found", one log event, one INFO line without song data, under 20 s.
void hostileCaseTest(HostileCase c) {
  nativeTest(
    '${c.folder} ends as ${c.kind.name}',
    timeout: const Timeout(Duration(seconds: 40)),
    () async {
      final server = await LoopbackServer.start(lrclibReply);
      addTearDown(server.close);
      final env = await NativePluginEnv.create();
      addTearDown(env.dispose);
      final record = await env.install(zipFixtureFolder('hostile/${c.folder}'));
      final secret = c.configValue;
      if (secret != null) {
        final write = await env.controller.setConfigValue(
          record.installId,
          'token',
          secret,
        );
        expect(write, PluginConfigWrite.written);
      }
      final h = await createHarness(
        [LyricsProviderRegistration(env.providerFor(record))],
        client: LrclibRoutingClient(server),
        database: env.db,
      );
      final appLog = <LogRecord>[];
      final level = Logger.root.level;
      addTearDown(() => Logger.root.level = level);
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(appLog.add);
      addTearDown(sub.cancel);

      final clock = Stopwatch()..start();
      await h.lookups.start(_target, auto: true);
      clock.stop();
      expect(clock.elapsed, lessThan(const Duration(seconds: 20)));

      // The failure the user would see, and nothing remembered as "no lyrics".
      final state = h.container.read(
        onlineLyricsLookupsProvider,
      )[_target.cacheKey];
      expect(state, isA<LookupFailed>());
      expect((state! as LookupFailed).kind, c.kind);
      expect(await env.db.watchOnlineLyrics(_target.cacheKey).first, isEmpty);

      // Exactly one event in the plugin's own log.
      final events = await env.events(record.installId);
      expect(events, hasLength(1));
      final event = events.single;
      expect(event['kind'], c.kind.name);
      expect(event['script'], 'search.js');
      if (c.console != null) expect(event['console'], c.console);
      if (c.message != null) expect(event['message'], contains(c.message));
      final requests = (event['requests']! as List)
          .cast<Map<String, Object?>>();
      expect([
        for (final r in requests) '${r['host']} ${r['path']} ${r['status']}',
      ], c.requests);
      for (final r in requests) {
        expect(r.keys, {'method', 'host', 'path', 'status', 'ms'});
        expect(r['path'], isNot(contains('?')));
      }

      // A config value is hidden in the file, whatever form it takes.
      if (secret != null) {
        final file = File(
          '${lyricsPluginLogDirOf(env.dataDir.path).path}/'
          '${record.installId}.jsonl',
        );
        expect(file.readAsStringSync(), isNot(contains(secret)));
        expect(file.readAsStringSync(), contains('***'));
      }

      // The app log: one short INFO line from the plugin host, no song data.
      final pluginLines = [
        for (final r in appLog)
          if (r.loggerName == 'lyrics_plugin') r,
      ];
      expect(pluginLines, hasLength(1));
      expect(pluginLines.single.level, Level.INFO);
      final host = c.appLogHost == null ? '' : ' host=${c.appLogHost}';
      expect(
        pluginLines.single.message,
        'Lyrics plugin "${record.name}" (${record.installId}) search.js '
        'failed: ${c.kind.name}$host',
      );
      for (final r in appLog) {
        expect(r.message, isNot(contains(_title)));
        expect(r.message, isNot(contains(_artist)));
        expect(r.error?.toString() ?? '', isNot(contains(_title)));
        if (secret != null) {
          expect(r.message, isNot(contains(secret)));
          expect(r.error?.toString() ?? '', isNot(contains(secret)));
          expect(r.stackTrace?.toString() ?? '', isNot(contains(secret)));
        }
      }
    },
  );
}

/// A run that finished well but printed far too much: no failure, a valid
/// empty answer, and a log event whose console is capped.
void consoleSpamTest(String folder) {
  nativeTest('$folder is capped in the log and the answer is kept', () async {
    final server = await LoopbackServer.start(lrclibReply);
    addTearDown(server.close);
    final env = await NativePluginEnv.create();
    addTearDown(env.dispose);
    final record = await env.install(zipFixtureFolder('hostile/$folder'));
    final h = await createHarness(
      [LyricsProviderRegistration(env.providerFor(record))],
      client: LrclibRoutingClient(server),
      database: env.db,
    );
    final appLog = <LogRecord>[];
    final level = Logger.root.level;
    addTearDown(() => Logger.root.level = level);
    Logger.root.level = Level.ALL;
    final sub = Logger.root.onRecord.listen(appLog.add);
    addTearDown(sub.cancel);

    await h.lookups.start(_target, auto: true);

    // `[]` is a valid "no result": it is the one case where "not found" is
    // the right thing to remember.
    expect(h.container.read(onlineLyricsLookupsProvider), isEmpty);
    final rows = await env.db.watchOnlineLyrics(_target.cacheKey).first;
    expect(rows.single.status, 'not_found');

    final events = await env.events(record.installId);
    expect(events, hasLength(1));
    expect(events.single['kind'], 'ok');
    final console = (events.single['console']! as List).cast<String>();
    expect(console, hasLength(50));
    expect(console.every((line) => line.length <= 500), isTrue);
    expect(console.first, startsWith('line 0 '));
    expect(console.last, matches(RegExp(r'^… \d+ lines dropped$')));
    expect(jsonEncode(events.single).length, lessThan(64 * 1024));
    // A run that did not fail writes nothing to the app log.
    expect([
      for (final r in appLog)
        if (r.loggerName == 'lyrics_plugin') r,
    ], isEmpty);
  });
}
