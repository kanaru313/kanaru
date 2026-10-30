import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_retry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_deadline.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';

import '../online/counting_http_client.dart';
import 'plugin_provider_env.dart';

void main() {
  late PluginProviderEnv env;
  late LyricsPluginRecord record;

  Future<void> setUpEnv({
    Duration outerDeadline = pluginRunOuterDeadline,
  }) async {
    env = await PluginProviderEnv.create(outerDeadline: outerDeadline);
    addTearDown(env.dispose);
    record = await env.install();
  }

  const tagQuery = LyricsQuery(
    title: 'Song',
    artist: 'Artist',
    album: 'Alb',
    duration: Duration(seconds: 200),
  );

  group('identity', () {
    setUp(setUpEnv);

    test('id, name and hosts come from the record', () {
      final provider = env.providerFor(record);
      expect(provider.id, record.installId);
      expect(provider.displayName, 'Demo');
      expect(provider.hosts, ['api.example.com']);
    });

    test('lookup answers null and runs no script', () async {
      final answer = await env
          .providerFor(record)
          .lookup(tagQuery, countingHttp());
      expect(answer, isNull);
      expect(env.runtime.requests, isEmpty);
    });
  });

  group('search', () {
    setUp(setUpEnv);

    test('sends the tags, or only the text of a manual search', () async {
      final provider = env.providerFor(record);
      await provider.search(tagQuery, countingHttp());
      await provider.search(
        const LyricsQuery(text: 'free text'),
        countingHttp(),
      );

      final inputs = [
        for (final r in env.runtime.requests) jsonDecode(r.inputJson),
      ];
      expect(inputs[0], {
        'title': 'Song',
        'artist': 'Artist',
        'album': 'Alb',
        'durationMs': 200000,
      });
      expect(inputs[1], {'text': 'free text'});
      expect(env.runtime.requests.first.entry, 'search.js');
    });

    test('missing tags are null', () async {
      await env
          .providerFor(record)
          .search(const LyricsQuery(title: 'Only'), countingHttp());
      expect(jsonDecode(env.runtime.requests.single.inputJson), {
        'title': 'Only',
        'artist': null,
        'album': null,
        'durationMs': null,
      });
    });

    test(
      'items become candidates of this provider; bad ones are dropped',
      () async {
        env.runtime.onSearch(
          okResult(
            jsonEncode([
              {
                'id': 'a1',
                'title': 'Song',
                'artist': 'Artist',
                'durationMs': 200000,
              },
              {'id': 'a2', 'title': 'Song', 'artist': ''},
              {
                'id': 'a3',
                'title': 'Song',
                'artist': 'Artist',
                'lyrics': '[00:01.00] hi',
              },
            ]),
          ),
        );

        final found = await env
            .providerFor(record)
            .search(tagQuery, countingHttp());

        expect(found.map((c) => c.remoteId), ['a1', 'a3']);
        expect(found.every((c) => c.providerId == record.installId), isTrue);
        expect(found.first.duration, const Duration(seconds: 200));
        expect(found.last.body?.syncedLrc, '[00:01.00] hi');
        // The dropped item is told in the plugin's log, with its number.
        await pumpLog();
        final event = env.events(record.installId).single;
        expect(event['kind'], 'ok');
        expect(event['console'], [
          'dropped: result #2: "artist" must be a non-empty string',
        ]);
      },
    );

    test('a non-array output is an invalid response', () async {
      env.runtime.onSearch(okResult('{"id":"x"}'));
      await expectLater(
        env.providerFor(record).search(tagQuery, countingHttp()),
        throwsA(
          isA<LyricsFetchException>().having(
            (e) => e.kind,
            'kind',
            LyricsFetchKind.invalidResponse,
          ),
        ),
      );
    });
  });

  group('fetch', () {
    setUp(setUpEnv);

    Future<LyricsBody?> fetchWith(String json) {
      env.runtime.onLyrics(okResult(json));
      return env.providerFor(record).fetch('r-1', countingHttp());
    }

    test('runs lyrics.js with the id', () async {
      await fetchWith('null');
      expect(env.runtime.requests.single.entry, 'lyrics.js');
      expect(jsonDecode(env.runtime.requests.single.inputJson), 'r-1');
    });

    test('null is no lyrics', () async {
      expect(await fetchWith('null'), isNull);
    });

    test('instrumental, lrc, txt and sniffed text', () async {
      expect((await fetchWith('{"instrumental":true}'))!.instrumental, isTrue);
      expect(
        (await fetchWith('{"data":"[00:01.00] a","type":"lrc"}'))!.syncedLrc,
        isNotNull,
      );
      expect(
        (await fetchWith('{"data":"words","type":"txt"}'))!.plain,
        'words',
      );
      expect(
        (await fetchWith('{"data":"[00:01.00] a"}'))!.syncedLrc,
        isNotNull,
      );
      expect((await fetchWith('{"data":"words"}'))!.plain, 'words');
    });
  });

  group('run contract', () {
    setUp(setUpEnv);

    Matcher failsWith(LyricsFetchKind kind) => throwsA(
      isA<LyricsFetchException>().having((e) => e.kind, 'kind', kind),
    );

    test('the run is registered while it runs and removed after', () async {
      final started = Completer<void>();
      final release = Completer<void>();
      env.runtime.handlers['search.js'] = (_, _, _) async {
        started.complete();
        await release.future;
        return okResult('[]');
      };
      final run = env.providerFor(record).search(tagQuery, countingHttp());
      await started.future;
      expect(env.store.runs.runningCount(record.installId), 1);
      release.complete();
      await run;
      expect(env.store.runs.runningCount(record.installId), 0);
    });

    test('a blocked plugin is skipped before anything is read', () async {
      env.store.runs.block(record.installId);
      await expectLater(
        env.providerFor(record).search(tagQuery, countingHttp()),
        throwsA(isA<LyricsSourceSkipped>()),
      );
      expect(env.runtime.requests, isEmpty);
    });

    test('a removed or missing record is skipped', () async {
      await env.db.customStatement(
        'UPDATE lyrics_plugins SET removed_at = 1 WHERE install_id = ?',
        [record.installId],
      );
      await expectLater(
        env.providerFor(record).fetch('x', countingHttp()),
        throwsA(isA<LyricsSourceSkipped>()),
      );
      expect(env.runtime.requests, isEmpty);
    });

    test('a missing package folder is an invalid response, logged', () async {
      await env.store.packageDir(record.packageDir).delete(recursive: true);
      await expectLater(
        env.providerFor(record).search(tagQuery, countingHttp()),
        failsWith(LyricsFetchKind.invalidResponse),
      );
      expect(env.runtime.requests, isEmpty);
      await pumpLog();
      expect(env.events(record.installId).single['kind'], 'invalidResponse');
    });

    test(
      'a package folder name that is not valid is an invalid response',
      () async {
        await env.db.customStatement(
          "UPDATE lyrics_plugins SET package_dir = '../../etc' WHERE install_id = ?",
          [record.installId],
        );
        await expectLater(
          env.providerFor(record).search(tagQuery, countingHttp()),
          failsWith(LyricsFetchKind.invalidResponse),
        );
      },
    );

    test('the package is read once per folder and handed over whole', () async {
      final provider = env.providerFor(record);
      await provider.search(tagQuery, countingHttp());
      await env.store.packageDir(record.packageDir).delete(recursive: true);
      await provider.search(tagQuery, countingHttp());

      expect(env.runtime.requests, hasLength(2));
      final request = env.runtime.requests.last;
      expect(request.files.map((f) => f.name).toSet(), {
        'search.js',
        'lyrics.js',
      });
    });

    test('config and stored map go into the run', () async {
      await env.db.customStatement(
        "UPDATE lyrics_plugin_data SET storage = '{\"k\":\"v\"}' "
        'WHERE install_id = ?',
        [record.installId],
      );
      await env.providerFor(record).search(tagQuery, countingHttp());
      expect(env.runtime.requests.single.storageJson, '{"k":"v"}');
      expect(env.runtime.requests.single.config, isEmpty);
    });

    test(
      'a changed storage map is saved while the record is the same',
      () async {
        env.runtime.onSearch(okResult('[]', storage: '{"seen":"1"}'));
        await env.providerFor(record).search(tagQuery, countingHttp());
        final row = await env.db.lyricsPluginDataFor(record.installId);
        expect(jsonDecode(row!.storage), {'seen': '1'});
      },
    );

    test('a run that outlived an update saves nothing', () async {
      env.runtime.handlers['search.js'] = (_, _, _) async {
        await env.db.customStatement(
          'UPDATE lyrics_plugins SET updated_at = updated_at + 1 '
          'WHERE install_id = ?',
          [record.installId],
        );
        return okResult('[]', storage: '{"late":"1"}');
      };
      await env.providerFor(record).search(tagQuery, countingHttp());
      final row = await env.db.lyricsPluginDataFor(record.installId);
      expect(jsonDecode(row!.storage), isEmpty);
    });

    test(
      'uninstall during a run cancels it and its late write is refused',
      () async {
        final started = Completer<void>();
        final release = Completer<void>();
        env.runtime.handlers['search.js'] = (_, _, cancel) async {
          started.complete();
          // Ignores the cancel and finishes late with a storage map.
          await release.future;
          return okResult('[]', storage: '{"late":"1"}');
        };
        final run = env.providerFor(record).search(tagQuery, countingHttp());
        final expectation = expectLater(
          run,
          throwsA(isA<LyricsSourceSkipped>()),
        );
        await started.future;

        await env.controller.uninstall(record.installId);
        release.complete();

        await expectation;
        expect(await env.db.lyricsPluginDataFor(record.installId), isNull);
        // Nothing is logged for a stopped run.
        await pumpLog();
        expect(env.events(record.installId), isEmpty);
        expect(
          Directory(env.store.logs.path).existsSync()
              ? Directory(env.store.logs.path).listSync()
              : const [],
          isEmpty,
        );
      },
    );

    test('a caller that left ends the run as abandoned', () async {
      env.runtime.handlers['search.js'] = (_, fetch, _) async {
        await fetch(
          PluginFetchCall(
            method: 'GET',
            url: Uri.parse('https://api.example.com/x'),
            headers: const [],
            body: Uint8List(0),
            deadline: const Duration(seconds: 5),
            maxSends: 10,
          ),
        );
        return const PluginRunResult(
          status: PluginRunStatus.cancelled,
          fetchFailure: PluginFetchFailure(
            kind: PluginFetchFailureKind.abandoned,
            message: 'abandoned',
          ),
        );
      };
      final http = LyricsHttp.forTesting(
        client: CountingHttpClient(),
        hosts: const ['api.example.com'],
        abandoned: () => true,
      );
      await expectLater(
        env.providerFor(record).search(tagQuery, http),
        throwsA(isA<LyricsRequestAbandoned>()),
      );
    });

    test('uninstall ends a run that listens for the cancel', () async {
      final started = Completer<void>();
      env.runtime.handlers['search.js'] = cancelledWhenStopped(started);
      final run = env.providerFor(record).search(tagQuery, countingHttp());
      final expectation = expectLater(
        run,
        throwsA(isA<LyricsSourceSkipped>()),
      );
      await started.future;
      await env.controller.uninstall(record.installId);
      await expectation;
      expect(env.store.runs.runningCount(record.installId), 0);
    });
  });

  group('outer deadline', () {
    setUp(() => setUpEnv(outerDeadline: const Duration(milliseconds: 60)));

    test(
      'a run that never starts is cancelled and counts as network',
      () async {
        PluginCancel? token;
        env.runtime.handlers['search.js'] = (_, _, cancel) {
          token = cancel;
          return Completer<PluginRunResult>().future;
        };
        await expectLater(
          env.providerFor(record).search(tagQuery, countingHttp()),
          throwsA(
            isA<LyricsFetchException>().having(
              (e) => e.kind,
              'kind',
              LyricsFetchKind.network,
            ),
          ),
        );
        expect(token!.isCancelled, isTrue);
        expect(env.store.runs.runningCount(record.installId), 0);
        await pumpLog();
        expect(env.events(record.installId).single['kind'], 'network');
      },
    );
  });
}
