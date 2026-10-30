import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_retry.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';
import 'package:logging/logging.dart';

import 'plugin_provider_env.dart';
import 'store/store_test_env.dart' show textField;

const _tags = LyricsQuery(
  title: 'Secret Title',
  artist: 'Secret Artist',
  album: 'Secret Album',
  duration: Duration(seconds: 200),
);

PluginFetchCall _call(String url) => PluginFetchCall(
  method: 'get',
  url: Uri.parse(url),
  headers: const [],
  body: Uint8List(0),
  deadline: const Duration(seconds: 5),
  maxSends: 10,
);

void main() {
  late PluginProviderEnv env;
  late LyricsPluginRecord record;
  late List<LogRecord> appLog;
  late StreamSubscription<LogRecord> sub;

  Future<void> setUpEnv({List<PluginConfigField> config = const []}) async {
    env = await PluginProviderEnv.create();
    addTearDown(env.dispose);
    record = await env.install(config: config);
    appLog = [];
    Logger.root.level = Level.ALL;
    sub = Logger.root.onRecord
        .where((r) => r.loggerName == 'lyrics_plugin')
        .listen(appLog.add);
    addTearDown(sub.cancel);
  }

  Future<Object?> searchError() async {
    try {
      await env.providerFor(record).search(_tags, countingHttp());
    } on Object catch (e) {
      await pumpLog();
      return e;
    }
    await pumpLog();
    return null;
  }

  group('plugin log file', () {
    setUp(setUpEnv);

    test('a failed run writes one well-formed event with all fields', () async {
      env.runtime.handlers['search.js'] = (_, fetch, _) async {
        await fetch(_call('https://api.example.com/v1/search?q=Secret#frag'));
        return const PluginRunResult(
          status: PluginRunStatus.scriptError,
          errorMessage: 'boom',
          jsError: PluginJsError(message: 'boom', stack: 'search.js:3:5'),
          logs: ['step one', 'step two'],
          fetchFailure: PluginFetchFailure(
            kind: PluginFetchFailureKind.network,
            message: 'network',
          ),
        );
      };

      final error = await searchError();

      expect(
        error,
        isA<LyricsFetchException>().having(
          (e) => e.kind,
          'kind',
          LyricsFetchKind.network,
        ),
      );
      final event = env.events(record.installId).single;
      expect(event.keys.toSet(), {
        'ts',
        'installId',
        'pluginName',
        'version',
        'script',
        'query',
        'kind',
        'message',
        'stack',
        'console',
        'requests',
      });
      expect(DateTime.parse(event['ts']! as String).isUtc, isTrue);
      expect(event['installId'], record.installId);
      expect(event['pluginName'], 'Demo');
      expect(event['version'], '1');
      expect(event['script'], 'search.js');
      expect(event['kind'], 'network');
      expect(event['message'], 'boom');
      expect(event['stack'], 'search.js:3:5');
      expect(event['console'], ['step one', 'step two']);
      expect((event['query']! as Map)['title'], 'Secret Title');
      final request = (event['requests']! as List).single as Map;
      expect(request['method'], 'GET');
      expect(request['host'], 'api.example.com');
      expect(request['path'], '/v1/search');
      expect(request['status'], isNull);
      expect(request['ms'], isA<int>());
    });

    test('every failing run adds a line', () async {
      env.runtime.onSearch(
        const PluginRunResult(
          status: PluginRunStatus.scriptError,
          errorKind: PluginRunErrorKind.server,
        ),
      );
      await searchError();
      await searchError();
      final lines = File('${env.store.logs.path}/${record.installId}.jsonl')
          .readAsLinesSync();
      expect(lines, hasLength(2));
      for (final line in lines) {
        expect(jsonDecode(line), isA<Map<String, Object?>>());
      }
    });

    test('a good run writes nothing; one that printed is written', () async {
      env.runtime.onSearch(okResult('[]'));
      await searchError();
      expect(env.events(record.installId), isEmpty);

      env.runtime.onSearch(okResult('[]', logs: ['hello']));
      await searchError();
      final event = env.events(record.installId).single;
      expect(event['kind'], 'ok');
      expect(event['console'], ['hello']);
      // A good run writes nothing to the app log.
      expect(appLog, isEmpty);
    });

    test(
      'a script that swallowed a failed fetch still fails the run',
      () async {
        env.runtime.onSearch(
          okResult(
            '[]',
            fetchFailure: const PluginFetchFailure(
              kind: PluginFetchFailureKind.network,
              message: 'network',
            ),
          ),
        );
        final error = await searchError();
        expect(error, isA<LyricsFetchException>());
        expect(env.events(record.installId).single['kind'], 'network');
      },
    );

    test('a log that cannot be written never fails the lookup', () async {
      // The log folder is a plain file.
      File(env.store.logs.path).writeAsStringSync('not a folder');
      env.runtime.onSearch(okResult('[]', logs: ['x']));
      await expectLater(
        env.providerFor(record).search(_tags, countingHttp()),
        completion(isEmpty),
      );
    });

    test('uninstall deletes the log file', () async {
      env.runtime.onSearch(okResult('[]', logs: ['x']));
      await searchError();
      expect(env.events(record.installId), hasLength(1));

      await env.controller.uninstall(record.installId);

      expect(env.events(record.installId), isEmpty);
      expect(
        File('${env.store.logs.path}/${record.installId}.jsonl').existsSync(),
        isFalse,
      );
    });

    test('stopped and skipped runs are not logged', () async {
      env.runtime.onSearch(
        const PluginRunResult(status: PluginRunStatus.cancelled),
      );
      await searchError();
      env.runtime.onSearch(const PluginRunResult(status: PluginRunStatus.busy));
      await searchError();
      expect(env.events(record.installId), isEmpty);
      expect(appLog, isEmpty);
    });
  });

  group('config values', () {
    setUp(() => setUpEnv(config: const [textField]));

    test('never reach the file, in any field', () async {
      await env.controller.setConfigValue(
        record.installId,
        'token',
        'supersecretvalue',
      );
      env.runtime.handlers['search.js'] = (request, fetch, _) async {
        final token = request.config['token']!;
        await fetch(_call('https://api.example.com/key/$token/x'));
        return PluginRunResult(
          status: PluginRunStatus.scriptError,
          errorMessage: 'bad token $token',
          jsError: PluginJsError(
            message: 'bad token $token',
            stack: 'at $token',
          ),
          logs: ['using $token'],
        );
      };

      await searchError();

      final text = File('${env.store.logs.path}/${record.installId}.jsonl')
          .readAsStringSync();
      expect(text, isNot(contains('supersecretvalue')));
      expect(text, contains('***'));
      expect(
        (env.events(record.installId).single['requests']! as List).single,
        containsPair('path', '/key/***/x'),
      );
      expect(
        appLog.map((r) => r.message).join(),
        isNot(contains('supersecret')),
      );
    });
  });

  group('setup and masking', () {
    setUp(() => setUpEnv(config: const [textField]));

    test(
      'config values are hidden in the query and the request host',
      () async {
        await env.controller.setConfigValue(
          record.installId,
          'token',
          'supersecretvalue',
        );
        env.runtime.handlers['search.js'] = (_, fetch, _) async {
          await fetch(_call('https://supersecretvalue.example.com/x'));
          return const PluginRunResult(
            status: PluginRunStatus.scriptError,
            errorKind: PluginRunErrorKind.server,
          );
        };
        await env
            .providerFor(record)
            .search(
              const LyricsQuery(text: 'find supersecretvalue now'),
              countingHttp(),
            )
            .then<void>((_) {}, onError: (Object _) {});
        await pumpLog();

        final text = File('${env.store.logs.path}/${record.installId}.jsonl')
            .readAsStringSync();
        expect(text, isNot(contains('supersecretvalue')));
        final event = env.events(record.installId).single;
        expect(event['query'], {'text': 'find *** now'});
        expect(
          ((event['requests']! as List).single as Map)['host'],
          '***.example.com',
        );
      },
    );
  });

  group('setup failures', () {
    test('an unreadable settings store is a logged invalid response', () async {
      env = await PluginProviderEnv.create(
        loadConfig: (_) async => throw StateError('secret=xyz'),
      );
      addTearDown(env.dispose);
      record = await env.install();

      expect(
        await searchError(),
        isA<LyricsFetchException>().having(
          (e) => e.kind,
          'kind',
          LyricsFetchKind.invalidResponse,
        ),
      );
      expect(env.runtime.requests, isEmpty);
      final event = env.events(record.installId).single;
      expect(event['kind'], 'invalidResponse');
      expect(event['message'], 'settings or storage could not be read');
      expect(
        File('${env.store.logs.path}/${record.installId}.jsonl')
            .readAsStringSync(),
        isNot(contains('xyz')),
      );
    });

    test('loading counts inside the outer deadline', () async {
      env = await PluginProviderEnv.create(
        outerDeadline: const Duration(milliseconds: 60),
        loadConfig: (_) => Completer<Map<String, String>>().future,
      );
      addTearDown(env.dispose);
      record = await env.install();

      expect(
        await searchError(),
        isA<LyricsFetchException>().having(
          (e) => e.kind,
          'kind',
          LyricsFetchKind.network,
        ),
      );
      expect(env.runtime.requests, isEmpty);
      expect(env.events(record.installId).single['kind'], 'network');
    });
  });

  group('app log', () {
    setUp(setUpEnv);

    test('one INFO line per failure without song data', () async {
      env.runtime.onSearch(
        const PluginRunResult(
          status: PluginRunStatus.timeout,
          errorMessage: 'slow',
          logs: ['Secret Title appears here'],
          jsError: PluginJsError(
            message: 'Secret Artist',
            stack: '/home/x/y.js',
          ),
        ),
      );
      await searchError();

      final line = appLog.single;
      expect(line.level, Level.INFO);
      expect(line.message, contains('Demo'));
      expect(line.message, contains(record.installId));
      expect(line.message, contains('search.js'));
      expect(line.message, contains('network'));
      for (final private in ['Secret', 'Alb', '/home', 'appears']) {
        expect(line.message, isNot(contains(private)));
      }
      expect(line.error, isNull);
    });

    test('a blocked address is named by its host only', () async {
      env.runtime.handlers['search.js'] = (_, fetch, _) async {
        // A first call that fails for another reason must not be named.
        await fetch(_call('https://api.example.com/first'));
        await fetch(_call('https://evil.example.net/path?k=v'));
        return const PluginRunResult(
          status: PluginRunStatus.scriptError,
          fetchFailure: PluginFetchFailure(
            kind: PluginFetchFailureKind.blockedHost,
            message: 'blocked',
          ),
        );
      };
      await searchError();
      final message = appLog.single.message;
      expect(message, contains('blockedHost'));
      expect(message, contains('host=evil.example.net'));
      expect(message, isNot(contains('api.example.com')));
      expect(message, isNot(contains('/path')));
      expect(message, isNot(contains('k=v')));
    });
  });

  group('failures become the right exception', () {
    setUp(setUpEnv);

    Future<Object?> failureOf(PluginRunResult result) async {
      env.runtime.onSearch(result);
      return searchError();
    }

    Matcher kind(LyricsFetchKind k, {Duration? retryAfter}) =>
        isA<LyricsFetchException>()
            .having((e) => e.kind, 'kind', k)
            .having((e) => e.retryAfter, 'retryAfter', retryAfter);

    test('the script error kinds', () async {
      expect(
        await failureOf(
          const PluginRunResult(
            status: PluginRunStatus.scriptError,
            errorKind: PluginRunErrorKind.rateLimited,
            retryAfterSec: 120,
          ),
        ),
        kind(
          LyricsFetchKind.rateLimited,
          retryAfter: const Duration(seconds: 120),
        ),
      );
      expect(
        await failureOf(
          const PluginRunResult(
            status: PluginRunStatus.scriptError,
            errorKind: PluginRunErrorKind.server,
          ),
        ),
        kind(LyricsFetchKind.server),
      );
      expect(
        await failureOf(
          const PluginRunResult(
            status: PluginRunStatus.scriptError,
            errorKind: PluginRunErrorKind.invalidResponse,
          ),
        ),
        kind(LyricsFetchKind.invalidResponse),
      );
    });

    test(
      'timeout is network; the other limits are invalid responses',
      () async {
        expect(
          await failureOf(
            const PluginRunResult(status: PluginRunStatus.timeout),
          ),
          kind(LyricsFetchKind.network),
        );
        for (final status in [
          PluginRunStatus.memory,
          PluginRunStatus.stack,
          PluginRunStatus.outputTooLarge,
          PluginRunStatus.internal,
        ]) {
          expect(
            await failureOf(PluginRunResult(status: status)),
            kind(LyricsFetchKind.invalidResponse),
            reason: status.name,
          );
        }
      },
    );

    test('busy is skipped and cancelled is abandoned', () async {
      expect(
        await failureOf(const PluginRunResult(status: PluginRunStatus.busy)),
        isA<LyricsSourceSkipped>(),
      );
      expect(
        await failureOf(
          const PluginRunResult(status: PluginRunStatus.cancelled),
        ),
        isA<LyricsRequestAbandoned>(),
      );
    });

    test('a bad output shape is an invalid response, logged', () async {
      expect(
        await failureOf(okResult('"text"')),
        kind(LyricsFetchKind.invalidResponse),
      );
      final event = env.events(record.installId).single;
      expect(event['kind'], 'invalidResponse');
      expect(event['message'], 'search output must be an array');
    });
  });
}
