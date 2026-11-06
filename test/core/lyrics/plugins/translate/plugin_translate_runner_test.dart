import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:kanaru/core/database/lyrics_plugin_queries.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/store/lyrics_plugin_installer.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_translate_spec.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_core.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_script_runner.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_deadline.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_run_log.dart';
import 'package:kanaru/core/lyrics/plugins/store/lyrics_plugin_dirs.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_gate.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_runner.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';

import '../../online/counting_http_client.dart';
import '../plugin_provider_env.dart';
import '../store/store_test_env.dart';

const _song = PluginTranslateSong(
  title: 'Secret Title',
  artist: 'Secret Artist',
  lyrics: 'secret lyrics line',
);

PluginRunResult _ok(List<String> texts) => okResult(
  jsonEncode([
    for (final t in texts) {'text': t},
  ]),
);

/// Polls until [condition] holds, failing the test after [limit].
Future<void> _until(
  bool Function() condition, {
  Duration limit = const Duration(seconds: 5),
}) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsed > limit) fail('condition not reached in $limit');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<Object?> _error(Future<Object?> future) async {
  try {
    await future;
  } on Object catch (e) {
    return e;
  }
  return null;
}

Matcher _failure(TranslationFailureKind kind) =>
    isA<TranslationException>().having((e) => e.kind, 'kind', kind);

void main() {
  late StoreEnv store;
  late ScriptedRuntime runtime;
  late PluginTranslateRunner runner;
  late PluginTranslateGate gate;
  late CountingHttpClient client;
  late LyricsPluginRecord record;
  final blocked = <String>[];

  PluginTranslateRunner makeRunner({
    Duration queueAllowance = pluginRunQueueAllowance,
  }) => PluginTranslateRunner(
    core: PluginRunCore(
      db: store.db,
      runtime: runtime,
      runs: store.runs,
      dirs: LyricsPluginDirs(store.dataDir.path),
      loadConfig: store.controller.configForRun,
      onNeedsConfig: (row) => blocked.add(row.installId),
    ),
    runLog: PluginRunLog(store.logs),
    client: () => client,
    gate: gate,
    queueAllowance: queueAllowance,
  );

  Future<LyricsPluginRecord> install({
    int timeoutSec = 15,
    List<PluginConfigField> config = const [],
    PluginKind kind = PluginKind.translate,
  }) => store.controller.installPackage(
    PluginPackage(
      manifest: PluginManifest(
        kind: kind,
        apiVersion: 1,
        name: 'Tr',
        version: 1,
        hosts: const ['api.example.com'],
        translateScript: 'translate.js',
        translate: PluginTranslateSpec(
          languages: const ['vi', 'en'],
          timeoutSec: timeoutSec,
        ),
        author: 'someone',
        config: config,
      ),
      files: const {'translate.js': '// translate'},
    ),
    const PluginInstallSource.file('tr.zip'),
  );

  setUp(() async {
    blocked.clear();
    store = await StoreEnv.create();
    runtime = ScriptedRuntime();
    client = CountingHttpClient();
    gate = PluginTranslateGate();
    runner = makeRunner();
    record = await install();
    addTearDown(() async {
      await PluginRunLog.idle();
      await store.dispose();
    });
  });

  Future<List<PluginTranslatedLine>> translate({
    List<String> lines = const ['a', 'b'],
    PluginTranslateSong? song = _song,
    bool Function()? allowed,
    bool Function()? stillWanted,
    String? id,
  }) => runner.translateChunk(
    id ?? record.installId,
    lines,
    'vi',
    song,
    allowed: allowed ?? () => true,
    stillWanted: stillWanted,
  );

  test('an ai-translate plugin runs and reports its spec', () async {
    // The package is read back through the manifest parser, so it must
    // declare the standard settings.
    const select = [PluginConfigOption(value: 'a', title: 'A')];
    final ai = await install(
      kind: PluginKind.aiTranslate,
      config: const [
        PluginConfigField(
          key: 'model',
          title: 'Model',
          mode: PluginConfigMode.select,
          options: select,
        ),
        PluginConfigField(
          key: 'style',
          title: 'Style',
          mode: PluginConfigMode.select,
          options: select,
        ),
        PluginConfigField(
          key: 'customInstruction',
          title: 'Instruction',
          mode: PluginConfigMode.input,
        ),
      ],
    );
    expect(ai.kind, PluginKind.aiTranslate);
    runtime.handlers['translate.js'] = (_, _, _) => _ok(['x', 'y']);
    expect(await translate(id: ai.installId), hasLength(2));
    expect((await runner.spec(ai.installId)).spec.languages, ['vi', 'en']);
  });

  group('instruction of the song', () {
    const select = [PluginConfigOption(value: 'a', title: 'A')];
    Future<LyricsPluginRecord> installAi({
      bool required = false,
      int? maxLength,
    }) => install(
      kind: PluginKind.aiTranslate,
      config: [
        const PluginConfigField(
          key: 'model',
          title: 'Model',
          mode: PluginConfigMode.select,
          options: select,
          defaultValue: 'a',
        ),
        const PluginConfigField(
          key: 'style',
          title: 'Style',
          mode: PluginConfigMode.select,
          options: select,
          defaultValue: 'a',
        ),
        PluginConfigField(
          key: 'customInstruction',
          title: 'Instruction',
          mode: PluginConfigMode.input,
          required: required,
          maxLength: maxLength,
        ),
      ],
    );

    Future<void> send(LyricsPluginRecord ai, Map<String, String> append) =>
        runner.translateChunk(
          ai.installId,
          const ['a', 'b'],
          'vi',
          _song,
          allowed: () => true,
          configAppend: append,
        );

    setUp(
      () => runtime.handlers['translate.js'] = (_, _, _) => _ok(['x', 'y']),
    );

    test('the script gets the shared text, a newline and the note', () async {
      final ai = await installAi();
      await store.controller.setConfigValue(
        ai.installId,
        'customInstruction',
        'A',
      );
      await send(ai, {'customInstruction': 'B'});
      expect(runtime.requests.last.config['customInstruction'], 'A\nB');
      await send(ai, const {});
      expect(runtime.requests.last.config['customInstruction'], 'A');
    });

    test('the note alone is the instruction when none is shared', () async {
      final ai = await installAi();
      await send(ai, {'customInstruction': 'B'});
      expect(runtime.requests.last.config['customInstruction'], 'B');
    });

    test('a required instruction is checked on the shared text only', () async {
      final ai = await installAi(required: true);
      expect(
        await _error(send(ai, {'customInstruction': 'B'})),
        _failure(TranslationFailureKind.needsConfig),
      );
      expect(runtime.requests, isEmpty);
    });

    test('the log hides the shared text and the note', () async {
      final ai = await installAi();
      await store.controller.setConfigValue(
        ai.installId,
        'customInstruction',
        'shared words here',
      );
      runtime.handlers['translate.js'] = (request, _, _) => PluginRunResult(
        status: PluginRunStatus.scriptError,
        errorKind: PluginRunErrorKind.quota,
        errorMessage: 'quota for ${request.config['customInstruction']}',
        logs: ['echo ${request.config['customInstruction']}'],
      );
      expect(
        await _error(send(ai, {'customInstruction': 'private note text'})),
        _failure(TranslationFailureKind.quotaExceeded),
      );
      await PluginRunLog.idle();
      final text = [
        for (final e in _events(store.logs, ai.installId)) jsonEncode(e),
      ].join();
      expect(text, isNot(contains('shared words')));
      expect(text, isNot(contains('private note')));
      expect(text, contains('***'));
    });

    test('the joined text is not held to the field maxLength', () async {
      final ai = await installAi(maxLength: 3);
      await store.controller.setConfigValue(
        ai.installId,
        'customInstruction',
        'abc',
      );
      await send(ai, {'customInstruction': 'defgh'});
      expect(runtime.requests.last.config['customInstruction'], 'abc\ndefgh');
    });
  });

  test(
    'an empty required field fails needsConfig, no script, no log',
    () async {
      final needy = await install(
        config: const [
          PluginConfigField(
            key: 'apiKey',
            title: 'Key',
            mode: PluginConfigMode.input,
            inputFormat: PluginInputFormat.secret,
            required: true,
          ),
        ],
      );
      expect(
        await _error(translate(id: needy.installId)),
        _failure(TranslationFailureKind.needsConfig),
      );
      expect(runtime.requests, isEmpty);
      expect(blocked, [needy.installId]);
      await PluginRunLog.idle();
      expect(
        Directory(store.logs.path).existsSync()
            ? Directory(store.logs.path).listSync()
            : [],
        isEmpty,
      );
    },
  );

  test('the script gets lines, to and song, and its lines come back', () async {
    runtime.handlers['translate.js'] = (_, _, _) => _ok(['x', 'y']);
    final lines = await translate();
    expect(lines.map((l) => l.text), ['x', 'y']);
    final request = runtime.requests.single;
    expect(jsonDecode(request.inputJson), {
      'lines': ['a', 'b'],
      'to': 'vi',
      'song': {
        'title': 'Secret Title',
        'artist': 'Secret Artist',
        'lyrics': 'secret lyrics line',
      },
    });
  });

  test('song is omitted when null, lyrics are capped', () async {
    runtime.handlers['translate.js'] = (_, _, _) => _ok(['x']);
    await translate(lines: ['a'], song: null);
    expect(jsonDecode(runtime.requests.last.inputJson), {
      'lines': ['a'],
      'to': 'vi',
    });
    await translate(
      lines: ['a'],
      song: PluginTranslateSong(title: 't', artist: 'a', lyrics: 'z' * 30000),
    );
    final song = (jsonDecode(runtime.requests.last.inputJson) as Map)['song'];
    expect((song as Map)['lyrics'], hasLength(20000));
  });

  test('wall time is the plugin timeoutSec', () async {
    final slow = await install(timeoutSec: 60);
    runtime.handlers['translate.js'] = (_, _, _) => _ok(['x']);
    await translate(lines: ['a'], id: slow.installId);
    expect(runtime.requests.single.timeout, const Duration(seconds: 60));
    await translate(lines: ['a']);
    expect(runtime.requests.last.timeout, const Duration(seconds: 15));
  });

  test('the outer deadline is counted from the turn, not the wait', () async {
    // Deadline = 50 ms + 1 s. The first run is held past it and times out;
    // the second waited that long but still gets its full time.
    runner = makeRunner(queueAllowance: const Duration(milliseconds: 50));
    record = await install(timeoutSec: 1);
    var calls = 0;
    runtime.handlers['translate.js'] = (_, _, _) async {
      if (calls++ == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1300));
      }
      return _ok(['x']);
    };
    final first = _error(translate(lines: ['a']));
    final second = translate(lines: ['b']);
    expect(await first, _failure(TranslationFailureKind.network));
    expect((await second).single.text, 'x');
  });

  test('a script that outlasts allowance plus timeout is network', () async {
    runner = makeRunner(queueAllowance: const Duration(milliseconds: 50));
    record = await install(timeoutSec: 1);
    runtime.handlers['translate.js'] = (_, _, _) async {
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      return _ok(['x']);
    };
    expect(
      await _error(translate(lines: ['a'])),
      _failure(TranslationFailureKind.network),
    );
  });

  test('a slow run succeeds as translate and times out as lyrics', () async {
    // Scaled down: 300 ms stands for the 30 s run. Translate has allowance
    // plus timeoutSec; the lyrics runner has only its short outer deadline.
    Future<PluginRunResult> slow(_, _, _) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return _ok(['x']);
    }

    runtime.handlers['translate.js'] = slow;
    runtime.handlers['search.js'] = slow;
    expect((await translate(lines: ['a'])).single.text, 'x');

    final lyrics = await store.controller.installPackage(
      testPackage(name: 'L'),
      const PluginInstallSource.file('l.zip'),
    );
    final lyricsRunner = PluginScriptRunner(
      db: store.db,
      runtime: runtime,
      runs: store.runs,
      runLog: PluginRunLog(store.logs),
      dirs: LyricsPluginDirs(store.dataDir.path),
      loadConfig: store.controller.configForRun,
      outerDeadline: const Duration(milliseconds: 60),
    );
    final error = await _error(
      lyricsRunner.run<String>(
        installId: lyrics.installId,
        script: PluginScript.search,
        input: const {},
        http: countingHttp(),
        read: (json, notes) => json,
      ),
    );
    expect(
      error,
      isA<LyricsFetchException>().having(
        (e) => e.kind,
        'kind',
        LyricsFetchKind.network,
      ),
    );
  });

  group('auth', () {
    PluginRunResult authError() => const PluginRunResult(
      status: PluginRunStatus.scriptError,
      errorKind: PluginRunErrorKind.auth,
      errorMessage: 'refused',
    );

    test('is noKey until a secret is stored, then badKey', () async {
      final keyed = await install(config: [secretField]);
      runtime.handlers['translate.js'] = (_, _, _) => authError();
      expect(
        await _error(translate(id: keyed.installId)),
        _failure(TranslationFailureKind.noKey),
      );
      await store.controller.setConfigValue(
        keyed.installId,
        'token',
        'secret-value-1',
      );
      expect(
        await _error(translate(id: keyed.installId)),
        _failure(TranslationFailureKind.badKey),
      );
    });

    test('is badKey for a plugin without secret fields', () async {
      runtime.handlers['translate.js'] = (_, _, _) => authError();
      expect(
        await _error(translate()),
        _failure(TranslationFailureKind.badKey),
      );
    });
  });

  test(
    'the app log says "Translate plugin" and names a blocked host',
    () async {
      final lines = <String>[];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord
          .where((r) => r.loggerName == 'lyrics_plugin')
          .listen((r) => lines.add(r.message));
      addTearDown(sub.cancel);
      runtime.handlers['translate.js'] = (_, fetch, _) async {
        await fetch(
          PluginFetchCall(
            method: 'get',
            url: Uri.parse('https://other.example.net/x'),
            headers: const [],
            body: Uint8List(0),
            deadline: const Duration(seconds: 5),
            maxSends: 10,
          ),
        );
        return const PluginRunResult(
          status: PluginRunStatus.scriptError,
          fetchFailure: PluginFetchFailure(
            kind: PluginFetchFailureKind.blockedHost,
            message: 'blocked',
          ),
        );
      };
      expect(
        await _error(translate()),
        _failure(TranslationFailureKind.blocked),
      );
      expect(lines.single, startsWith('Translate plugin "Tr"'));
      expect(lines.single, contains('failed: blocked'));
      expect(lines.single, contains('host=other.example.net'));
    },
  );

  test('lyrics are cut without splitting a surrogate pair', () {
    final text = '${'a' * 19999}\u{1F600}tail';
    final json = PluginTranslateSong(
      title: 't',
      artist: 'a',
      lyrics: text,
    ).toJson();
    expect(json['lyrics'], 'a' * 19999);
    final plain = PluginTranslateSong(
      title: 't',
      artist: 'a',
      lyrics: '${'a' * 19998}\u{1F600}tail',
    ).toJson();
    expect((plain['lyrics']! as String).length, 20000);
  });

  test('a plugin of another kind or an unknown one is server', () async {
    final lyrics = await store.controller.installPackage(
      testPackage(name: 'L'),
      const PluginInstallSource.file('l.zip'),
    );
    expect(
      await _error(translate(id: lyrics.installId)),
      _failure(TranslationFailureKind.server),
    );
    expect(
      await _error(translate(id: 'missing')),
      _failure(TranslationFailureKind.server),
    );
    expect(runtime.requests, isEmpty);
  });

  test('a removed plugin is server', () async {
    await store.controller.uninstall(record.installId);
    expect(await _error(translate()), _failure(TranslationFailureKind.server));
  });

  test('the log keeps sizes, never the lyrics', () async {
    runtime.handlers['translate.js'] = (_, _, _) => const PluginRunResult(
      status: PluginRunStatus.scriptError,
      errorKind: PluginRunErrorKind.quota,
      errorMessage: 'out of quota',
      logs: ['console line'],
    );
    expect(
      await _error(translate(lines: ['hello', 'world'])),
      _failure(TranslationFailureKind.quotaExceeded),
    );
    await PluginRunLog.idle();
    final text = [
      for (final e in _events(store.logs, record.installId)) jsonEncode(e),
    ].join();
    expect(text, contains('translate.js'));
    expect(text, contains('"lines":2'));
    expect(text, contains('"chars":10'));
    expect(text, contains('"to":"vi"'));
    expect(text, isNot(contains('hello')));
    expect(text, isNot(contains('Secret Title')));
    expect(text, isNot(contains('secret lyrics')));
  });

  test('a bad output is invalidResponse and is logged', () async {
    runtime.handlers['translate.js'] = (_, _, _) => _ok(['only one']);
    expect(
      await _error(translate()),
      _failure(TranslationFailureKind.invalidResponse),
    );
    await PluginRunLog.idle();
    expect(_events(store.logs, record.installId), hasLength(1));
  });

  test('storage written by the script is kept', () async {
    runtime.handlers['translate.js'] = (_, _, _) =>
        okResult('[{"text":"x"},{"text":"y"}]', storage: '{"k":"v"}');
    await translate();
    final data = await store.db.lyricsPluginDataFor(record.installId);
    expect(data?.storage, '{"k":"v"}');
  });

  test('storage is not written after an update of the record', () async {
    runtime.handlers['translate.js'] = (_, _, _) async {
      await store.db.customStatement(
        'UPDATE lyrics_plugins SET updated_at = updated_at + 1 '
        'WHERE install_id = ?',
        [record.installId],
      );
      return okResult('[{"text":"x"},{"text":"y"}]', storage: '{"k":"v"}');
    };
    await translate();
    final data = await store.db.lyricsPluginDataFor(record.installId);
    expect(jsonDecode(data!.storage), isEmpty);
  });

  test('three chunks run one at a time', () async {
    var maxActive = 0;
    runtime.handlers['translate.js'] = (_, _, _) async {
      maxActive = maxActive < runtime.active ? runtime.active : maxActive;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return _ok(['x']);
    };
    await Future.wait([
      for (var i = 0; i < 3; i++) translate(lines: ['a']),
    ]);
    expect(maxActive, 1);
    expect(runtime.requests, hasLength(3));
  });

  test('a waiter no longer wanted is dropped without a run', () async {
    final hold = Completer<void>();
    runtime.handlers['translate.js'] = (_, _, _) async {
      await hold.future;
      return _ok(['x']);
    };
    var wanted = true;
    final first = translate(lines: ['a']);
    await _until(() => runtime.requests.length == 1);
    final second = _error(translate(lines: ['b'], stillWanted: () => wanted));
    await _until(() => gate.waiting == 1);
    wanted = false;
    hold.complete();
    await first;
    expect(await second, isA<TranslationSuperseded>());
    expect(runtime.requests, hasLength(1));
  });

  test('allowed false before the chunk sends nothing', () async {
    expect(
      await _error(translate(allowed: () => false)),
      _failure(TranslationFailureKind.blocked),
    );
    expect(runtime.requests, isEmpty);
  });

  test('a chunk refused inside the gate does not block the next', () async {
    runtime.handlers['translate.js'] = (_, _, _) => _ok(['x', 'y']);
    var allowed = false;
    final refused = _error(translate(allowed: () => allowed));
    final next = translate();
    expect(await refused, _failure(TranslationFailureKind.blocked));
    expect(await next, hasLength(2));
    allowed = true;
  });

  test('allowed is asked live before every send', () async {
    var allowed = true;
    runtime.handlers['translate.js'] = (_, fetch, _) async {
      await fetch(_call());
      allowed = false;
      await fetch(_call());
      return _ok(['x', 'y']);
    };
    await translate(allowed: () => allowed);
    // The first send reached the client; the second was refused.
    expect(client.opened, 1);
  });

  test('spec reads the declared block, hosts and settings', () async {
    final info = await runner.spec(record.installId);
    expect(info.spec.languages, ['vi', 'en']);
    expect(info.hosts, ['api.example.com']);
  });

  test('spec errors: missing, other kind', () async {
    expect(
      await _error(runner.spec('missing')),
      _failure(TranslationFailureKind.server),
    );
    final lyrics = await store.controller.installPackage(
      testPackage(name: 'L'),
      const PluginInstallSource.file('l.zip'),
    );
    expect(
      await _error(runner.spec(lyrics.installId)),
      _failure(TranslationFailureKind.server),
    );
  });

  test('spec comes from the record, not from the package files', () async {
    store.packageDir(record.packageDir).deleteSync(recursive: true);
    final info = await runner.spec(record.installId);
    expect(info.spec.languages, ['vi', 'en']);
  });

  test('spec of a record with no translate spec is invalidResponse', () async {
    await store.db.customStatement(
      'UPDATE lyrics_plugins SET translate_spec = NULL WHERE install_id = ?',
      [record.installId],
    );
    expect(
      await _error(runner.spec(record.installId)),
      _failure(TranslationFailureKind.invalidResponse),
    );
    await PluginRunLog.idle();
    final events = _events(store.logs, record.installId);
    expect(events, hasLength(1));
    expect(jsonEncode(events.single), contains('no translate spec'));
  });

  test('an uninstall during a run cancels it', () async {
    final started = Completer<void>();
    runtime.handlers['translate.js'] = cancelledWhenStopped(started);
    final run = _error(translate());
    await started.future;
    await store.controller.uninstall(record.installId);
    expect(await run, _failure(TranslationFailureKind.server));
  });
}

List<Map<String, Object?>> _events(Directory logs, String installId) {
  final file = File('${logs.path}/$installId.jsonl');
  if (!file.existsSync()) return const [];
  return [
    for (final line in file.readAsLinesSync())
      jsonDecode(line) as Map<String, Object?>,
  ];
}

PluginFetchCall _call() => PluginFetchCall(
  method: 'get',
  url: Uri.parse('https://api.example.com/v1/t'),
  headers: const [],
  body: Uint8List(0),
  deadline: const Duration(seconds: 5),
  maxSends: 10,
);
