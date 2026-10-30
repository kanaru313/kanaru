@Tags(['native'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';
import 'package:kanaru/core/plugin_runtime/rust_plugin_runtime.dart';
import 'package:kanaru/src/rust/frb_generated.dart';

/// The debug library `cargo build --manifest-path rust/Cargo.toml` makes.
final _libraryPath =
    '${Directory.current.path}/rust/target/debug/'
    'librust_lib_kanaru.so';
final _libraryMissing = !File(_libraryPath).existsSync();

const _runtime = RustPluginRuntime();

PluginRunRequest _request(
  String code, {
  Duration? timeout,
  String storageJson = '',
  Map<String, String> config = const {},
}) => PluginRunRequest(
  files: [PluginSourceFile(name: 'search.js', code: code)],
  entry: 'search.js',
  inputJson: '{"q":"hello"}',
  timeout: timeout,
  config: config,
  storageJson: storageJson,
);

PluginFetchAnswer _ok(String body, {int sends = 1}) => PluginFetchAnswer(
  outcome: PluginFetchOutcome.ok,
  status: 200,
  url: Uri.parse('https://api.test/final'),
  headers: const [('content-type', 'text/plain; charset=utf-8')],
  bytes: Uint8List.fromList(utf8.encode(body)),
  sends: sends,
);

/// Set when a fetcher that must not be called is called. Checked after the
/// run: a `fail()` inside the fetcher would be swallowed as a network failure.
bool _unexpectedFetch = false;

Future<PluginFetchAnswer> _noFetch(PluginFetchCall call) async {
  _unexpectedFetch = true;
  return PluginFetchAnswer.failure(PluginFetchOutcome.network);
}

/// Why the library could not be loaded (for example a stale build), if so.
String? _initProblem;

void nativeTest(String name, Future<void> Function() body) {
  test(name, () async {
    final problem = _initProblem;
    if (problem != null) {
      markTestSkipped(problem);
      return;
    }
    _unexpectedFetch = false;
    await body();
    expect(_unexpectedFetch, isFalse, reason: 'the script must not fetch');
  });
}

void main() {
  setUpAll(() async {
    if (_libraryMissing) return;
    if (RustLib.instance.initialized) return;
    try {
      await RustLib.init(externalLibrary: ExternalLibrary.open(_libraryPath));
    } on Object catch (error) {
      _initProblem =
          'Native library cannot be loaded (${error.runtimeType}); rebuild '
          'with `cargo build --manifest-path rust/Cargo.toml`';
    }
  });

  group(
    'native plugin runtime',
    skip: _libraryMissing
        ? 'Native library not built: run '
              '`cargo build --manifest-path rust/Cargo.toml` first '
              '(expected at $_libraryPath)'
        : null,
    () {
      nativeTest('a script runs and returns its data', () async {
        final result = await _runtime.run(
          _request(
            'function execute(input) {'
            '  console.log("hi " + input.q + " " + localConfig.getItem("k"));'
            '  return Response.success({got: input.q});'
            '}',
            config: {'k': 'secret'},
          ),
          fetch: _noFetch,
        );
        expect(result.status, PluginRunStatus.ok);
        expect(jsonDecode(result.outputJson), {'got': 'hello'});
        expect(result.logs, ['hi hello secret']);
        expect(result.jsError, isNull);
        expect(result.fetchFailure, isNull);
        expect(result.storage, isNull);
      });

      nativeTest('a fetch round trip goes through the Dart fetcher', () async {
        final calls = <PluginFetchCall>[];
        final result = await _runtime.run(
          _request(
            'function execute() {'
            '  var r = fetch("https://api.test/s?x=1", {method: "POST",'
            '    headers: {"x-a": "b"}, body: "payload", queries: {q: "a b"}});'
            '  return Response.success({s: r.status, t: r.text(), u: r.url,'
            '    ct: r.header("content-type")});'
            '}',
          ),
          fetch: (call) async {
            calls.add(call);
            return _ok('answer ü');
          },
        );
        expect(result.status, PluginRunStatus.ok, reason: result.errorMessage);
        expect(jsonDecode(result.outputJson), {
          's': 200,
          't': 'answer ü',
          'u': 'https://api.test/final',
          'ct': 'text/plain; charset=utf-8',
        });
        expect(calls, hasLength(1));
        final call = calls.single;
        expect(call.method, 'POST');
        expect(call.url, Uri.parse('https://api.test/s?x=1&q=a%20b'));
        expect(call.headers, contains(('x-a', 'b')));
        expect(utf8.decode(call.body), 'payload');
        expect(call.maxSends, 10);
        expect(call.deadline, greaterThan(Duration.zero));
        expect(call.deadline, lessThanOrEqualTo(const Duration(seconds: 15)));
      });

      nativeTest('the deadline shrinks with the run timeout', () async {
        late Duration seen;
        await _runtime.run(
          _request(
            'function execute() { fetch("https://api.test/"); '
            'return Response.success(1); }',
            timeout: const Duration(seconds: 2),
          ),
          fetch: (call) async {
            seen = call.deadline;
            return _ok('x');
          },
        );
        expect(seen, lessThanOrEqualTo(const Duration(seconds: 2)));
        expect(seen, greaterThan(Duration.zero));
      });

      nativeTest(
        'reported sends lower the sends left for the next fetch',
        () async {
          final left = <int>[];
          final result = await _runtime.run(
            _request(
              'function execute() { fetch("https://api.test/1"); '
              'fetch("https://api.test/2"); return Response.success(1); }',
            ),
            fetch: (call) async {
              left.add(call.maxSends);
              return _ok('x', sends: 3);
            },
          );
          expect(result.status, PluginRunStatus.ok);
          expect(left, [10, 7]);
        },
      );

      test(
        'a fetcher that throws is a network failure the script sees',
        () async {
          final result = await _runtime.run(
            _request(
              'function execute() {'
              '  try { fetch("https://api.test/"); } catch (e) {'
              '    return Response.success(e.name);'
              '  }'
              '  return Response.success("no error");'
              '}',
            ),
            fetch: (call) async => throw StateError('socket closed'),
          );
          expect(result.status, PluginRunStatus.ok);
          expect(jsonDecode(result.outputJson), 'NetworkError');
          expect(result.fetchFailure?.kind, PluginFetchFailureKind.network);
        },
      );

      nativeTest('refused fetches do not use up the send budget', () async {
        var blocked = 0;
        final result = await _runtime.run(
          _request(
            'function execute() {'
            '  for (var i = 0; i < 12; i++) {'
            '    try { fetch("https://api.test/" + i); } catch (e) {}'
            '  }'
            '  var r = fetch("https://api.test/ok");'
            '  return Response.success(r.status);'
            '}',
          ),
          fetch: (call) async {
            if (call.url.path == '/ok') return _ok('fine');
            blocked++;
            return PluginFetchAnswer.failure(
              blocked.isEven
                  ? PluginFetchOutcome.blockedHost
                  : PluginFetchOutcome.notConsented,
            );
          },
        );
        expect(blocked, 12);
        expect(result.status, PluginRunStatus.ok, reason: result.errorMessage);
        expect(jsonDecode(result.outputJson), 200);
        expect(result.fetchFailure?.kind, PluginFetchFailureKind.notConsented);
      });

      nativeTest(
        'a failed run keeps logs, js error and fetch failure',
        () async {
          final result = await _runtime.run(
            _request(
              'function execute() {'
              '  console.log("before");'
              '  try { fetch("https://api.test/"); } catch (e) {}'
              '  throw new Error("kaput");'
              '}',
            ),
            fetch: (call) async =>
                PluginFetchAnswer.failure(PluginFetchOutcome.blockedHost),
          );
          expect(result.status, PluginRunStatus.scriptError);
          expect(result.logs, ['before']);
          expect(result.jsError?.message, contains('kaput'));
          expect(result.jsError?.stack, contains('search.js'));
          expect(result.fetchFailure?.kind, PluginFetchFailureKind.blockedHost);
          expect(result.errorMessage, contains('kaput'));
          expect(result.errorKind, PluginRunErrorKind.invalidResponse);
        },
      );

      nativeTest('an error response carries its kind and retry hint', () async {
        final result = await _runtime.run(
          _request(
            'function execute() { return Response.error("slow", '
            '{kind: "rateLimited", retryAfterSec: 9}); }',
            storageJson: '',
          ),
          fetch: _noFetch,
        );
        expect(result.status, PluginRunStatus.scriptError);
        expect(result.errorKind, PluginRunErrorKind.rateLimited);
        expect(result.retryAfterSec, 9);
        expect(result.errorMessage, 'slow');
        expect(result.jsError, isNull);
      });

      nativeTest('changed storage comes back after ok', () async {
        final result = await _runtime.run(
          _request(
            'function execute() { localStorage.setItem("k", "v"); '
            'return Response.success(1); }',
          ),
          fetch: _noFetch,
        );
        expect(result.status, PluginRunStatus.ok);
        expect(jsonDecode(result.storage!), {'k': 'v'});
      });

      nativeTest('a timeout stops the script and returns no storage', () async {
        final stopwatch = Stopwatch()..start();
        final result = await _runtime.run(
          _request(
            'function execute() { console.log("start"); '
            'localStorage.setItem("k", "v"); while (true) {} }',
            timeout: const Duration(milliseconds: 300),
          ),
          fetch: _noFetch,
        );
        expect(result.status, PluginRunStatus.timeout);
        expect(result.storage, isNull);
        expect(result.logs, ['start']);
        expect(result.jsError, isNotNull);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      });

      test(
        'a fetcher slower than the deadline is cut by the runtime',
        () async {
          final never = Completer<PluginFetchAnswer>();
          addTearDown(() {
            if (!never.isCompleted) {
              never.complete(
                PluginFetchAnswer.failure(PluginFetchOutcome.network),
              );
            }
          });
          final result = await _runtime.run(
            _request(
              'function execute() { console.log("waiting"); '
              'fetch("https://api.test/"); return Response.success(1); }',
              timeout: const Duration(milliseconds: 400),
            ),
            fetch: (call) => never.future,
          );
          expect(result.status, PluginRunStatus.timeout);
          expect(result.logs, ['waiting']);
        },
      );

      nativeTest('cancel during a fetch ends the run as cancelled', () async {
        final cancel = PluginCancel();
        final fetching = Completer<void>();
        final never = Completer<PluginFetchAnswer>();
        addTearDown(() {
          if (!never.isCompleted) {
            never.complete(
              PluginFetchAnswer.failure(PluginFetchOutcome.network),
            );
          }
        });
        final future = _runtime.run(
          _request(
            'function execute() { console.log("before"); '
            'fetch("https://api.test/"); return Response.success(1); }',
          ),
          fetch: (call) {
            fetching.complete();
            return never.future;
          },
          cancel: cancel,
        );
        await fetching.future;
        final stopwatch = Stopwatch()..start();
        cancel.cancel();
        final result = await future;
        expect(result.status, PluginRunStatus.cancelled);
        expect(result.logs, ['before']);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      });

      nativeTest('cancel before the start runs no script', () async {
        final cancel = PluginCancel()..cancel();
        final result = await _runtime.run(
          _request(
            'console.log("loaded"); '
            'function execute() { return Response.success(1); }',
          ),
          fetch: _noFetch,
          cancel: cancel,
        );
        expect(result.status, PluginRunStatus.cancelled);
        expect(result.logs, isEmpty);
        expect(result.jsError, isNull);
        expect(result.outputJson, isEmpty);
      });

      nativeTest('a script that does not compile is a script error', () async {
        final result = await _runtime.run(
          _request('function execute( {'),
          fetch: _noFetch,
        );
        expect(result.status, PluginRunStatus.scriptError);
        expect(result.jsError, isNotNull);
      });

      nativeTest(
        'check accepts a good script and reports a syntax error',
        () async {
          expect(
            await _runtime.check('a.js', 'function execute() { return 1; }'),
            isNull,
          );
          final problem = await _runtime.check('a.js', 'var a = 1;\nvar = ;');
          expect(problem, isNotNull);
          expect(problem!.message, isNotEmpty);
          expect(problem.line, 2);
        },
      );
    },
  );
}
