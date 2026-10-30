import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';
import 'package:kanaru/core/plugin_runtime/rust_plugin_runtime.dart';
import 'package:kanaru/src/rust/api/plugin_runtime.dart' as native;

native.PluginScriptResult _native({
  native.PluginScriptStatus status = native.PluginScriptStatus.ok,
  String outputJson = '',
  String errorMessage = '',
  native.PluginErrorKind errorKind = native.PluginErrorKind.none,
  int? retryAfterSec,
  native.PluginJsError? jsError,
  List<String> logs = const [],
  native.PluginFetchFailure? fetchFailure,
  String? storageJson,
}) => native.PluginScriptResult(
  status: status,
  outputJson: outputJson,
  errorMessage: errorMessage,
  errorKind: errorKind,
  retryAfterSec: retryAfterSec,
  jsError: jsError,
  logs: logs,
  fetchFailure: fetchFailure,
  storageJson: storageJson,
);

native.PluginFetchRequest _fetchRequest({
  String url = 'https://api.test/x?q=1',
  int deadlineMs = 1500,
  int maxSends = 7,
}) => native.PluginFetchRequest(
  method: 'POST',
  url: url,
  headers: const [('accept', 'a/b'), ('accept', 'c/d')],
  body: Uint8List.fromList([1, 2, 3]),
  deadlineMs: deadlineMs,
  maxSends: maxSends,
);

void main() {
  group('status', () {
    const pairs = {
      native.PluginScriptStatus.ok: PluginRunStatus.ok,
      native.PluginScriptStatus.scriptError: PluginRunStatus.scriptError,
      native.PluginScriptStatus.timeout: PluginRunStatus.timeout,
      native.PluginScriptStatus.memory: PluginRunStatus.memory,
      native.PluginScriptStatus.stack: PluginRunStatus.stack,
      native.PluginScriptStatus.cancelled: PluginRunStatus.cancelled,
      native.PluginScriptStatus.outputTooLarge: PluginRunStatus.outputTooLarge,
      native.PluginScriptStatus.internal: PluginRunStatus.internal,
      native.PluginScriptStatus.busy: PluginRunStatus.busy,
    };

    test('every native status has a public status', () {
      expect(pairs.length, native.PluginScriptStatus.values.length);
      expect(pairs.values.toSet().length, PluginRunStatus.values.length);
    });

    for (final entry in pairs.entries) {
      test('${entry.key.name} keeps logs, js error and fetch failure', () {
        final result = runResultFromNative(
          _native(
            status: entry.key,
            errorMessage: 'why',
            errorKind: native.PluginErrorKind.server,
            logs: const ['one', 'two'],
            jsError: const native.PluginJsError(
              message: 'boom',
              stack: 'at execute (search.js:3)',
            ),
            fetchFailure: const native.PluginFetchFailure(
              kind: native.PluginFetchFailureKind.rateLimited,
              retryAfterSec: 12,
              message: 'slow down',
            ),
          ),
        );
        expect(result.status, entry.value);
        expect(result.errorMessage, 'why');
        expect(result.errorKind, PluginRunErrorKind.server);
        expect(result.logs, ['one', 'two']);
        expect(result.jsError?.message, 'boom');
        expect(result.jsError?.stack, 'at execute (search.js:3)');
        expect(result.fetchFailure?.kind, PluginFetchFailureKind.rateLimited);
        expect(result.fetchFailure?.retryAfterSec, 12);
        expect(result.fetchFailure?.message, 'slow down');
      });

      test('${entry.key.name} with no extra data maps the nulls', () {
        final result = runResultFromNative(_native(status: entry.key));
        expect(result.status, entry.value);
        expect(result.jsError, isNull);
        expect(result.fetchFailure, isNull);
        expect(result.retryAfterSec, isNull);
        expect(result.storage, isNull);
        expect(result.logs, isEmpty);
        expect(result.outputJson, isEmpty);
        expect(result.errorKind, PluginRunErrorKind.none);
      });
    }
  });

  group('result fields', () {
    test('ok carries the output and the storage', () {
      final result = runResultFromNative(
        _native(outputJson: '{"a":1}', storageJson: '{"k":"v"}'),
      );
      expect(result.outputJson, '{"a":1}');
      expect(result.storage, '{"k":"v"}');
    });

    test('an empty stack becomes null, the message stays', () {
      final result = runResultFromNative(
        _native(
          status: native.PluginScriptStatus.scriptError,
          jsError: const native.PluginJsError(message: 'oops', stack: ''),
        ),
      );
      expect(result.jsError?.message, 'oops');
      expect(result.jsError?.stack, isNull);
    });

    test('error kinds map both ways of the enum', () {
      const kinds = {
        native.PluginErrorKind.none: PluginRunErrorKind.none,
        native.PluginErrorKind.rateLimited: PluginRunErrorKind.rateLimited,
        native.PluginErrorKind.invalidResponse:
            PluginRunErrorKind.invalidResponse,
        native.PluginErrorKind.server: PluginRunErrorKind.server,
      };
      expect(kinds.length, native.PluginErrorKind.values.length);
      for (final entry in kinds.entries) {
        final result = runResultFromNative(
          _native(errorKind: entry.key, retryAfterSec: 30),
        );
        expect(result.errorKind, entry.value);
        expect(result.retryAfterSec, 30);
      }
    });

    test('every fetch failure kind maps, with and without retry', () {
      const kinds = {
        native.PluginFetchFailureKind.network: PluginFetchFailureKind.network,
        native.PluginFetchFailureKind.blockedHost:
            PluginFetchFailureKind.blockedHost,
        native.PluginFetchFailureKind.notConsented:
            PluginFetchFailureKind.notConsented,
        native.PluginFetchFailureKind.abandoned:
            PluginFetchFailureKind.abandoned,
        native.PluginFetchFailureKind.invalidRequest:
            PluginFetchFailureKind.invalidRequest,
        native.PluginFetchFailureKind.invalidResponse:
            PluginFetchFailureKind.invalidResponse,
        native.PluginFetchFailureKind.rateLimited:
            PluginFetchFailureKind.rateLimited,
      };
      expect(kinds.length, native.PluginFetchFailureKind.values.length);
      for (final entry in kinds.entries) {
        final bare = runResultFromNative(
          _native(
            fetchFailure: native.PluginFetchFailure(
              kind: entry.key,
              message: 'm',
            ),
          ),
        );
        expect(bare.fetchFailure?.kind, entry.value);
        expect(bare.fetchFailure?.retryAfterSec, isNull);
        final timed = runResultFromNative(
          _native(
            fetchFailure: native.PluginFetchFailure(
              kind: entry.key,
              retryAfterSec: 5,
              message: 'm',
            ),
          ),
        );
        expect(timed.fetchFailure?.retryAfterSec, 5);
      }
    });

    test('logs cannot be changed by the caller', () {
      final result = runResultFromNative(_native(logs: ['a']));
      expect(() => result.logs.add('b'), throwsUnsupportedError);
    });
  });

  group('request', () {
    test('maps files, config, input and storage', () {
      final request = nativeRequestFrom(
        const PluginRunRequest(
          files: [
            PluginSourceFile(name: 'search.js', code: 'a'),
            PluginSourceFile(name: 'util.js', code: 'b'),
          ],
          entry: 'search.js',
          inputJson: '{"q":1}',
          timeout: Duration(seconds: 2),
          config: {'k': 'v', 'k2': 'v2'},
          storageJson: '{"s":"1"}',
        ),
        42,
      );
      expect(request.job, 42);
      expect(request.entry, 'search.js');
      expect(request.inputJson, '{"q":1}');
      expect(request.timeoutMs, 2000);
      expect(request.storageJson, '{"s":"1"}');
      expect(request.config, [('k', 'v'), ('k2', 'v2')]);
      expect(request.files.map((f) => (f.name, f.code)), [
        ('search.js', 'a'),
        ('util.js', 'b'),
      ]);
    });

    test('a zero, negative or sub-millisecond timeout is 1 ms, not 0', () {
      for (final timeout in [
        Duration.zero,
        const Duration(seconds: -3),
        const Duration(microseconds: 400),
      ]) {
        final request = nativeRequestFrom(
          PluginRunRequest(
            files: const [],
            entry: 'a.js',
            inputJson: 'null',
            timeout: timeout,
          ),
          1,
        );
        expect(request.timeoutMs, 1, reason: '$timeout');
      }
    });

    test('no timeout means 0 (the runtime maximum)', () {
      final request = nativeRequestFrom(
        const PluginRunRequest(files: [], entry: 'a.js', inputJson: 'null'),
        1,
      );
      expect(request.timeoutMs, 0);
      expect(request.storageJson, isEmpty);
      expect(request.config, isEmpty);
    });
  });

  group('fetch call', () {
    test('carries method, url, headers, body, deadline and max sends', () {
      final call = fetchCallFromNative(_fetchRequest())!;
      expect(call.method, 'POST');
      expect(call.url, Uri.parse('https://api.test/x?q=1'));
      expect(call.headers, [('accept', 'a/b'), ('accept', 'c/d')]);
      expect(call.body, [1, 2, 3]);
      expect(call.deadline, const Duration(milliseconds: 1500));
      expect(call.maxSends, 7);
    });

    test('a url that does not parse gives no call', () {
      expect(fetchCallFromNative(_fetchRequest(url: 'http://[bad')), isNull);
    });
  });

  group('fetch answer', () {
    const outcomes = {
      PluginFetchOutcome.ok: native.PluginFetchOutcome.ok,
      PluginFetchOutcome.network: native.PluginFetchOutcome.network,
      PluginFetchOutcome.blockedHost: native.PluginFetchOutcome.blockedHost,
      PluginFetchOutcome.notConsented: native.PluginFetchOutcome.notConsented,
      PluginFetchOutcome.abandoned: native.PluginFetchOutcome.abandoned,
      PluginFetchOutcome.invalidRequest:
          native.PluginFetchOutcome.invalidRequest,
      PluginFetchOutcome.invalidResponse:
          native.PluginFetchOutcome.invalidResponse,
      PluginFetchOutcome.rateLimited: native.PluginFetchOutcome.rateLimited,
    };

    test('every outcome maps', () {
      expect(outcomes.length, PluginFetchOutcome.values.length);
      expect(outcomes.length, native.PluginFetchOutcome.values.length);
      for (final entry in outcomes.entries) {
        final response = fetchResponseToNative(
          PluginFetchAnswer.failure(entry.key),
        );
        expect(response.outcome, entry.value);
        expect(response.status, 0);
        expect(response.url, isEmpty);
        expect(response.body, isEmpty);
        expect(response.sends, 0);
      }
    });

    test('an ok answer keeps status, final url, headers, bytes and sends', () {
      final response = fetchResponseToNative(
        PluginFetchAnswer(
          outcome: PluginFetchOutcome.ok,
          status: 404,
          url: Uri.parse('https://api.test/final'),
          headers: const [('content-type', 'text/html'), ('x', 'y')],
          bytes: Uint8List.fromList([9, 8]),
          sends: 3,
        ),
      );
      expect(response.status, 404);
      expect(response.url, 'https://api.test/final');
      expect(response.headers, [('content-type', 'text/html'), ('x', 'y')]);
      expect(response.body, [9, 8]);
      expect(response.sends, 3);
      expect(response.retryAfterSec, isNull);
    });

    test('rate limited keeps the retry hint', () {
      final response = fetchResponseToNative(
        PluginFetchAnswer.failure(
          PluginFetchOutcome.rateLimited,
          retryAfterSec: 60,
        ),
      );
      expect(response.retryAfterSec, 60);
    });

    test('out of range numbers are clamped', () {
      final response = fetchResponseToNative(
        PluginFetchAnswer(
          outcome: PluginFetchOutcome.ok,
          status: 70000,
          retryAfterSec: -4,
          sends: -1,
        ),
      );
      expect(response.status, 0xFFFF);
      expect(response.retryAfterSec, 0);
      expect(response.sends, 0);
    });
  });

  group('answerFetch', () {
    test('hands the call to the fetcher and maps its answer', () async {
      PluginFetchCall? seen;
      final response = await answerFetch((call) async {
        seen = call;
        return PluginFetchAnswer(
          outcome: PluginFetchOutcome.ok,
          status: 200,
          bytes: Uint8List.fromList([7]),
        );
      }, _fetchRequest());
      expect(seen?.maxSends, 7);
      expect(response.outcome, native.PluginFetchOutcome.ok);
      expect(response.status, 200);
      expect(response.body, [7]);
    });

    test('a fetcher that throws is a network failure', () async {
      final response = await answerFetch(
        (call) async => throw StateError('socket closed'),
        _fetchRequest(),
      );
      expect(response.outcome, native.PluginFetchOutcome.network);
      expect(response.sends, 0);
    });

    test('a fetcher that throws synchronously is a network failure', () async {
      final response = await answerFetch(
        (call) => throw ArgumentError('bad'),
        _fetchRequest(),
      );
      expect(response.outcome, native.PluginFetchOutcome.network);
    });

    test('an ok answer without a final url gets the call url', () async {
      final response = await answerFetch(
        (call) async => PluginFetchAnswer(outcome: PluginFetchOutcome.ok),
        _fetchRequest(),
      );
      expect(response.url, 'https://api.test/x?q=1');
    });

    test('a url that does not parse is refused without a fetch', () async {
      var called = false;
      final response = await answerFetch((call) async {
        called = true;
        return PluginFetchAnswer.failure(PluginFetchOutcome.network);
      }, _fetchRequest(url: 'http://[bad'));
      expect(called, isFalse);
      expect(response.outcome, native.PluginFetchOutcome.invalidRequest);
      expect(response.sends, 0);
    });
  });

  group('cancel token', () {
    test('notifies listeners once and stays cancelled', () {
      final cancel = PluginCancel();
      var calls = 0;
      cancel.addListener(() => calls++);
      expect(cancel.isCancelled, isFalse);
      cancel.cancel();
      cancel.cancel();
      expect(cancel.isCancelled, isTrue);
      expect(calls, 1);
    });

    test('a throwing listener does not stop the others', () {
      final cancel = PluginCancel();
      var called = false;
      cancel.addListener(() => throw StateError('bad'));
      cancel.addListener(() => called = true);
      expect(cancel.cancel, returnsNormally);
      expect(called, isTrue);
    });

    test('a removed listener is not called', () {
      final cancel = PluginCancel();
      var calls = 0;
      void listener() => calls++;
      cancel.addListener(listener);
      cancel.removeListener(listener);
      cancel.cancel();
      expect(calls, 0);
    });
  });
}
