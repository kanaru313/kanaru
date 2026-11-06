import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_core.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_log.dart';
import 'package:kanaru/core/lyrics/plugins/store/lyrics_plugin_dirs.dart';
import 'package:kanaru/core/lyrics/plugins/store/lyrics_plugin_installer.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';
import 'package:kanaru/core/sources/source_plugin_runner.dart';

import '../lyrics/online/counting_http_client.dart';
import '../lyrics/plugins/plugin_provider_env.dart';
import '../lyrics/plugins/store/store_test_env.dart';

const _streamUrl = 'https://media.example.com/audio?sig=SECRETSIG';

PluginRunResult _error(
  PluginRunErrorKind kind, [
  String message = 'from the script',
]) => PluginRunResult(
  status: PluginRunStatus.scriptError,
  errorKind: kind,
  errorMessage: message,
);

PluginRunResult _status(PluginRunStatus status) =>
    PluginRunResult(status: status, errorMessage: 'runtime text');

PluginFetchCall _call() => PluginFetchCall(
  method: 'get',
  url: Uri.parse('https://api.example.com/v1/search'),
  headers: const [],
  body: Uint8List(0),
  deadline: const Duration(seconds: 5),
  maxSends: 10,
);

Future<Object?> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on Object catch (e) {
    return e;
  }
  return null;
}

Matcher _failure(SourceFailureKind kind, {String? message}) {
  var matcher = isA<SourceFailure>().having((e) => e.kind, 'kind', kind);
  if (message != null) {
    matcher = matcher.having((e) => e.message, 'message', message);
  }
  return matcher;
}

void main() {
  late StoreEnv store;
  late ScriptedRuntime runtime;
  late CountingHttpClient client;
  late SourcePluginRunner runner;
  late LyricsPluginRecord record;
  late Set<String> consented;

  SourcePluginRunner makeRunner({
    Duration outerDeadline = const Duration(seconds: 60),
    Future<PluginConfigMap> Function(String installId)? loadConfig,
  }) => SourcePluginRunner(
    core: PluginRunCore(
      db: store.db,
      runtime: runtime,
      runs: store.runs,
      dirs: LyricsPluginDirs(store.dataDir.path),
      loadConfig: loadConfig ?? store.controller.configForRun,
      outerDeadline: outerDeadline,
    ),
    runLog: PluginRunLog(store.logs),
    client: () => client,
    consented: consented.contains,
  );

  Future<LyricsPluginRecord> install({
    List<PluginConfigField> config = const [],
  }) => store.controller.installPackage(
    PluginPackage(
      manifest: PluginManifest(
        kind: PluginKind.source,
        apiVersion: 1,
        name: 'Src',
        version: 1,
        hosts: const ['api.example.com'],
        searchScript: 'search.js',
        streamScript: 'stream.js',
        author: 'someone',
        config: config,
      ),
      files: const {'search.js': '// search', 'stream.js': '// stream'},
    ),
    const PluginInstallSource.file('src.zip'),
  );

  setUp(() async {
    store = await StoreEnv.create();
    runtime = ScriptedRuntime();
    client = CountingHttpClient();
    record = await install();
    consented = {record.installId};
    runner = makeRunner();
    addTearDown(() async {
      await PluginRunLog.idle();
      await store.dispose();
    });
  });

  void onSearch(FutureOr<PluginRunResult> Function() answer) =>
      runtime.handlers['search.js'] = (_, _, _) => answer();
  void onStream(FutureOr<PluginRunResult> Function() answer) =>
      runtime.handlers['stream.js'] = (_, _, _) => answer();

  Future<SourceSearchPage> search({
    String? id,
    String? next,
    bool Function()? abandoned,
  }) => runner.search(
    id ?? record.installId,
    'some song',
    next: next,
    abandoned: abandoned,
  );

  Future<List<Map<String, Object?>>> events() async {
    await PluginRunLog.idle();
    final file = File('${store.logs.path}/${record.installId}.jsonl');
    if (!file.existsSync()) return const [];
    return [
      for (final line in file.readAsLinesSync())
        jsonDecode(line) as Map<String, Object?>,
    ];
  }

  group('a search that succeeds', () {
    test('sends the query and reads the page', () async {
      onSearch(
        () => okResult(
          jsonEncode({
            'items': [
              {'id': 'v1', 'title': 'One', 'durationMs': 0},
              {'id': '', 'title': 'dropped'},
            ],
            'next': 'p2',
          }),
        ),
      );

      final page = await search();

      expect(jsonDecode(runtime.requests.single.inputJson), {
        'query': 'some song',
      });
      expect(runtime.requests.single.entry, 'search.js');
      expect(page.items.single.id, 'v1');
      expect(page.items.single.duration, isNull);
      expect(page.next, 'p2');
    });

    test('sends next on a later page and drops a next that loops', () async {
      onSearch(() => okResult(jsonEncode({'items': [], 'next': 'p2'})));

      final page = await search(next: 'p2');

      expect(jsonDecode(runtime.requests.single.inputJson), {
        'query': 'some song',
        'next': 'p2',
      });
      expect(page.next, isNull);
    });

    test('a dropped item is noted in the log of a run that printed', () async {
      onSearch(
        () => okResult(
          jsonEncode({
            'items': [
              {'id': '', 'title': 'x'},
            ],
          }),
          logs: ['hello'],
        ),
      );

      await search();

      final event = (await events()).single;
      expect(event['kind'], 'ok');
      expect(event['script'], 'search.js');
      expect(event['console'], ['hello', startsWith('dropped: item #1')]);
    });

    test('a quiet run that ended well writes no log', () async {
      onSearch(() => okResult(jsonEncode({'items': []})));

      await search();

      expect(await events(), isEmpty);
    });
  });

  group('a stream that succeeds', () {
    test('sends the id, and fresh only when true', () async {
      onStream(
        () => okResult(
          jsonEncode({
            'url': _streamUrl,
            'headers': {'Cookie': 'c=1', 'Range': 'bytes=0-'},
            'mimeType': 'audio/webm',
            'bitrate': 0,
            'expiresAtMs': 1790000000000,
          }),
          logs: ['resolved'],
        ),
      );

      final stream = await runner.stream(record.installId, 'v1');
      await runner.stream(record.installId, 'v1', fresh: true);

      expect(jsonDecode(runtime.requests.first.inputJson), {'id': 'v1'});
      expect(jsonDecode(runtime.requests.last.inputJson), {
        'id': 'v1',
        'fresh': true,
      });
      expect(runtime.requests.first.entry, 'stream.js');
      expect(stream.url, Uri.parse(_streamUrl));
      expect(stream.headers['cookie'], 'c=1');
      expect(stream.headers.containsKey('range'), isFalse);
      expect(stream.bitrate, isNull);
      expect(stream.expiresAt?.millisecondsSinceEpoch, 1790000000000);
      // The console is kept; the URL and its headers never reach the log.
      final text = jsonEncode(await events());
      expect(text, contains('resolved'));
      expect(text, isNot(contains('SECRETSIG')));
      expect(text, isNot(contains('c=1')));
    });
  });

  group('consent', () {
    test('without it nothing runs and no request reaches the client', () async {
      consented.clear();
      runtime.handlers['search.js'] = (_, fetch, _) async {
        await fetch(_call());
        return okResult(jsonEncode({'items': []}));
      };

      expect(
        await _failureOf(search()),
        _failure(SourceFailureKind.notConsented),
      );
      expect(
        await _failureOf(runner.stream(record.installId, 'v1')),
        _failure(SourceFailureKind.notConsented),
      );
      expect(runtime.requests, isEmpty);
      expect(client.opened, 0);
      expect(await events(), isEmpty);
    });

    test('a withdrawal stops the next send of a run going', () async {
      runtime.handlers['search.js'] = (_, fetch, _) async {
        await fetch(_call());
        consented.clear();
        final second = await fetch(_call());
        expect(second.outcome, PluginFetchOutcome.notConsented);
        return okResult(jsonEncode({'items': []}));
      };

      expect(
        await _failureOf(search()),
        _failure(SourceFailureKind.notConsented),
      );
      expect(client.opened, 1);
    });

    test('a refused fetch the script caught still fails', () async {
      onSearch(
        () => okResult(
          jsonEncode({'items': []}),
          fetchFailure: const PluginFetchFailure(
            kind: PluginFetchFailureKind.notConsented,
            message: 'refused',
          ),
        ),
      );

      expect(
        await _failureOf(search()),
        _failure(SourceFailureKind.notConsented),
      );
    });
  });

  group('skipped', () {
    test('a missing plugin, of another kind, or removed', () async {
      final lyrics = await store.controller.installPackage(
        testPackage(name: 'L'),
        const PluginInstallSource.file('l.zip'),
      );
      consented.add(lyrics.installId);
      consented.add('plugin-000000000000');
      expect(
        await _failureOf(search(id: 'plugin-000000000000')),
        _failure(SourceFailureKind.skipped),
      );
      expect(
        await _failureOf(search(id: lyrics.installId)),
        _failure(SourceFailureKind.skipped),
      );
      await store.controller.uninstall(record.installId);
      expect(await _failureOf(search()), _failure(SourceFailureKind.skipped));
      expect(runtime.requests, isEmpty);
    });

    test('a plugin being updated or uninstalled', () async {
      store.runs.block(record.installId);
      addTearDown(() => store.runs.unblock(record.installId));

      expect(
        await _failureOf(runner.stream(record.installId, 'v1')),
        _failure(SourceFailureKind.skipped),
      );
      expect(runtime.requests, isEmpty);
    });

    test('an uninstall during a run stops it, nothing is logged', () async {
      final started = Completer<void>();
      runtime.handlers['search.js'] = cancelledWhenStopped(started);

      final run = _failureOf(search());
      await started.future;
      await store.controller.uninstall(record.installId);

      expect(await run, _failure(SourceFailureKind.skipped));
      expect(await events(), isEmpty);
    });

    test('a call abandoned before it starts runs nothing', () async {
      expect(
        await _failureOf(search(abandoned: () => true)),
        _failure(SourceFailureKind.skipped),
      );
      expect(runtime.requests, isEmpty);
    });

    test('a call abandoned during the run sends nothing more', () async {
      var gone = false;
      runtime.handlers['search.js'] = (_, fetch, _) async {
        await fetch(_call());
        gone = true;
        final second = await fetch(_call());
        return PluginRunResult(
          status: PluginRunStatus.scriptError,
          errorMessage: 'fetch failed',
          fetchFailure: second.outcome == PluginFetchOutcome.abandoned
              ? const PluginFetchFailure(
                  kind: PluginFetchFailureKind.abandoned,
                  message: 'abandoned',
                )
              : null,
        );
      };

      expect(
        await _failureOf(search(abandoned: () => gone)),
        _failure(SourceFailureKind.skipped),
      );
      expect(client.opened, 1);
      expect(await events(), isEmpty);
    });

    test(
      'a result that arrives after the call was abandoned is dropped',
      () async {
        var gone = false;
        runtime.handlers['search.js'] = (_, _, _) {
          gone = true;
          return okResult(jsonEncode({'items': []}));
        };

        expect(
          await _failureOf(search(abandoned: () => gone)),
          _failure(SourceFailureKind.skipped),
        );
      },
    );
  });

  test('an empty required field is needsConfig: no run, no log', () async {
    final needy = await install(
      config: const [
        PluginConfigField(
          key: 'apiKey',
          title: 'Key',
          mode: PluginConfigMode.input,
          inputFormat: PluginInputFormat.text,
          required: true,
        ),
      ],
    );
    consented.add(needy.installId);

    expect(
      await _failureOf(search(id: needy.installId)),
      _failure(SourceFailureKind.needsConfig),
    );
    expect(runtime.requests, isEmpty);
  });

  group('script errors', () {
    test('auth keeps the script message and is logged', () async {
      onSearch(() => _error(PluginRunErrorKind.auth, 'sign in please'));

      expect(
        await _failureOf(search()),
        _failure(SourceFailureKind.auth, message: 'sign in please'),
      );
      final event = (await events()).single;
      expect(event['kind'], 'auth');
      expect(event['message'], 'sign in please');
      expect(event['query'], {'query': 'some song'});
    });

    test('rateLimited and quota are rateLimited', () async {
      for (final kind in [
        PluginRunErrorKind.rateLimited,
        PluginRunErrorKind.quota,
      ]) {
        onSearch(() => _error(kind));
        expect(
          await _failureOf(search()),
          _failure(SourceFailureKind.rateLimited, message: 'from the script'),
          reason: kind.name,
        );
      }
    });

    test('invalidResponse and server are unavailable', () async {
      for (final kind in [
        PluginRunErrorKind.invalidResponse,
        PluginRunErrorKind.server,
      ]) {
        onStream(() => _error(kind));
        expect(
          await _failureOf(runner.stream(record.installId, 'v1')),
          _failure(SourceFailureKind.unavailable, message: 'from the script'),
          reason: kind.name,
        );
      }
    });

    test(
      'a thrown error after a failed fetch is network, no message',
      () async {
        onSearch(
          () => const PluginRunResult(
            status: PluginRunStatus.scriptError,
            errorMessage: 'TypeError at search.js:3',
            fetchFailure: PluginFetchFailure(
              kind: PluginFetchFailureKind.network,
              message: 'network',
            ),
          ),
        );

        expect(
          await _failureOf(search()),
          _failure(SourceFailureKind.network, message: ''),
        );
      },
    );

    test('a thrown error without a fetch is unavailable', () async {
      onSearch(
        () => const PluginRunResult(
          status: PluginRunStatus.scriptError,
          errorMessage: 'TypeError',
        ),
      );

      expect(
        await _failureOf(search()),
        _failure(SourceFailureKind.unavailable, message: ''),
      );
    });
  });

  group('runtime ends', () {
    test('a timeout is network', () async {
      onSearch(() => _status(PluginRunStatus.timeout));
      expect(await _failureOf(search()), _failure(SourceFailureKind.network));
    });

    test('a full pool is busy and is not logged', () async {
      onSearch(() => _status(PluginRunStatus.busy));
      expect(await _failureOf(search()), _failure(SourceFailureKind.busy));
      expect(await events(), isEmpty);
    });

    test('a runtime failure is internal', () async {
      onSearch(() => _status(PluginRunStatus.internal));
      expect(await _failureOf(search()), _failure(SourceFailureKind.internal));
    });

    test('memory or stack is unavailable', () async {
      for (final status in [PluginRunStatus.memory, PluginRunStatus.stack]) {
        onSearch(() => _status(status));
        expect(
          await _failureOf(search()),
          _failure(SourceFailureKind.unavailable),
        );
      }
    });
  });

  group('invalidOutput', () {
    test('a bad shape is logged with the problem', () async {
      onStream(
        () => okResult(
          jsonEncode({'url': 'http://media.example.com/a', 'mimeType': 'x'}),
        ),
      );

      expect(
        await _failureOf(runner.stream(record.installId, 'v1')),
        _failure(SourceFailureKind.invalidOutput),
      );
      final event = (await events()).single;
      expect(event['kind'], 'invalidOutput');
      expect(event['script'], 'stream.js');
      expect(event['message'], contains('"url"'));
    });

    test('output over the limit', () async {
      onSearch(() => _status(PluginRunStatus.outputTooLarge));
      expect(
        await _failureOf(search()),
        _failure(SourceFailureKind.invalidOutput),
      );
    });
  });

  group('setup failures', () {
    test('a package that cannot be read is internal and logged', () async {
      store.packageDir(record.packageDir).deleteSync(recursive: true);

      expect(await _failureOf(search()), _failure(SourceFailureKind.internal));
      expect((await events()).single['kind'], 'internal');
    });

    test('loading that takes too long is network', () async {
      runner = makeRunner(
        outerDeadline: const Duration(milliseconds: 50),
        loadConfig: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return const {};
        },
      );

      expect(await _failureOf(search()), _failure(SourceFailureKind.network));
      expect(runtime.requests, isEmpty);
    });
  });
}
