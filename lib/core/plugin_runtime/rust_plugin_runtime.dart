import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../src/rust/api/plugin_runtime.dart' as native;
import '../native/rust_library.dart';
import 'plugin_runtime.dart';

final _log = Logger('plugin_runtime');

const _maxU16 = 0xFFFF;
const _maxU32 = 0xFFFFFFFF;

/// [PluginRuntime] backed by the Rust QuickJS sandbox. The native library
/// loads on the first run. This is the only file that sees the generated
/// bindings.
class RustPluginRuntime implements PluginRuntime {
  const RustPluginRuntime();

  @override
  Future<PluginRunResult> run(
    PluginRunRequest request, {
    required PluginFetcher fetch,
    PluginCancel? cancel,
  }) async {
    try {
      await ensureRustLibraryLoaded();
    } on Object {
      // ensureRustLibraryLoaded already logged the cause.
      return _internalFailure('The plugin runtime could not be loaded');
    }
    int? job;
    void stop() {
      final id = job;
      if (id != null) native.cancelPluginJob(job: id);
    }

    try {
      final id = job = native.beginPluginJob();
      // A token cancelled before the start still goes through Rust: the id is
      // freed there and the run answers cancelled without running any script.
      if (cancel != null) {
        cancel.addListener(stop);
        if (cancel.isCancelled) stop();
      }
      final result = await native.runPluginScript(
        request: nativeRequestFrom(request, id),
        fetch: (call) => answerFetch(fetch, call),
      );
      return runResultFromNative(result);
    } catch (error, stackTrace) {
      // Log the type only: the text of a bridge error may echo the request.
      _log.severe('Plugin run failed: ${error.runtimeType}', null, stackTrace);
      try {
        // Frees the id when the run call never reached Rust; idempotent.
        stop();
      } on Object {
        // Nothing more to do; the result below says the run failed.
      }
      return _internalFailure('The plugin runtime call failed');
    } finally {
      cancel?.removeListener(stop);
    }
  }

  @override
  Future<PluginScriptProblem?> check(String fileName, String code) async {
    await ensureRustLibraryLoaded();
    final problem = await native.checkPluginScript(name: fileName, code: code);
    if (problem == null) return null;
    return PluginScriptProblem(
      message: problem.message,
      line: problem.line > 0 ? problem.line : null,
    );
  }
}

PluginRunResult _internalFailure(String message) =>
    PluginRunResult(status: PluginRunStatus.internal, errorMessage: message);

// ---------------------------------------------------------------------------
// Mapping between the public types and the generated bindings. Top level so
// tests can reach them without the native library.
// ---------------------------------------------------------------------------

/// Public request to the bindings' request for job [job].
@visibleForTesting
native.PluginScriptRequest nativeRequestFrom(
  PluginRunRequest request,
  int job,
) => native.PluginScriptRequest(
  job: job,
  files: [
    for (final file in request.files)
      native.PluginSourceFile(name: file.name, code: file.code),
  ],
  entry: request.entry,
  inputJson: request.inputJson,
  // 0 means "runtime maximum" to Rust, so a zero or sub-millisecond timeout
  // becomes the shortest real one.
  timeoutMs: request.timeout == null
      ? 0
      : _clamp(max(1, request.timeout!.inMilliseconds), _maxU32),
  config: [
    for (final entry in request.config.entries) (entry.key, entry.value),
  ],
  storageJson: request.storageJson,
);

/// The bindings' result to the public result, nothing dropped.
@visibleForTesting
PluginRunResult runResultFromNative(native.PluginScriptResult result) {
  final jsError = result.jsError;
  final failure = result.fetchFailure;
  return PluginRunResult(
    status: switch (result.status) {
      native.PluginScriptStatus.ok => PluginRunStatus.ok,
      native.PluginScriptStatus.scriptError => PluginRunStatus.scriptError,
      native.PluginScriptStatus.timeout => PluginRunStatus.timeout,
      native.PluginScriptStatus.memory => PluginRunStatus.memory,
      native.PluginScriptStatus.stack => PluginRunStatus.stack,
      native.PluginScriptStatus.cancelled => PluginRunStatus.cancelled,
      native.PluginScriptStatus.outputTooLarge =>
        PluginRunStatus.outputTooLarge,
      native.PluginScriptStatus.internal => PluginRunStatus.internal,
      native.PluginScriptStatus.busy => PluginRunStatus.busy,
    },
    outputJson: result.outputJson,
    errorMessage: result.errorMessage,
    errorKind: switch (result.errorKind) {
      native.PluginErrorKind.none => PluginRunErrorKind.none,
      native.PluginErrorKind.rateLimited => PluginRunErrorKind.rateLimited,
      native.PluginErrorKind.invalidResponse =>
        PluginRunErrorKind.invalidResponse,
      native.PluginErrorKind.server => PluginRunErrorKind.server,
    },
    retryAfterSec: result.retryAfterSec,
    jsError: jsError == null
        ? null
        : PluginJsError(
            message: jsError.message,
            stack: jsError.stack.isEmpty ? null : jsError.stack,
          ),
    logs: List.unmodifiable(result.logs),
    fetchFailure: failure == null
        ? null
        : PluginFetchFailure(
            kind: switch (failure.kind) {
              native.PluginFetchFailureKind.network =>
                PluginFetchFailureKind.network,
              native.PluginFetchFailureKind.blockedHost =>
                PluginFetchFailureKind.blockedHost,
              native.PluginFetchFailureKind.notConsented =>
                PluginFetchFailureKind.notConsented,
              native.PluginFetchFailureKind.abandoned =>
                PluginFetchFailureKind.abandoned,
              native.PluginFetchFailureKind.invalidRequest =>
                PluginFetchFailureKind.invalidRequest,
              native.PluginFetchFailureKind.invalidResponse =>
                PluginFetchFailureKind.invalidResponse,
              native.PluginFetchFailureKind.rateLimited =>
                PluginFetchFailureKind.rateLimited,
            },
            retryAfterSec: failure.retryAfterSec,
            message: failure.message,
          ),
    storage: result.storageJson,
  );
}

/// The bindings' fetch request to the public call. Null when the script's URL
/// is not a valid [Uri] (the caller answers `invalidRequest`).
@visibleForTesting
PluginFetchCall? fetchCallFromNative(native.PluginFetchRequest request) {
  final url = Uri.tryParse(request.url);
  if (url == null) return null;
  return PluginFetchCall(
    method: request.method,
    url: url,
    headers: request.headers,
    body: request.body,
    deadline: Duration(milliseconds: request.deadlineMs),
    maxSends: request.maxSends,
  );
}

/// The public answer to the bindings' response. Numbers are clamped into the
/// ranges the bindings encode, so an odd answer cannot fail the encoding.
@visibleForTesting
native.PluginFetchResponse fetchResponseToNative(PluginFetchAnswer answer) =>
    native.PluginFetchResponse(
      outcome: switch (answer.outcome) {
        PluginFetchOutcome.ok => native.PluginFetchOutcome.ok,
        PluginFetchOutcome.network => native.PluginFetchOutcome.network,
        PluginFetchOutcome.blockedHost => native.PluginFetchOutcome.blockedHost,
        PluginFetchOutcome.notConsented =>
          native.PluginFetchOutcome.notConsented,
        PluginFetchOutcome.abandoned => native.PluginFetchOutcome.abandoned,
        PluginFetchOutcome.invalidRequest =>
          native.PluginFetchOutcome.invalidRequest,
        PluginFetchOutcome.invalidResponse =>
          native.PluginFetchOutcome.invalidResponse,
        PluginFetchOutcome.rateLimited => native.PluginFetchOutcome.rateLimited,
      },
      status: _clamp(answer.status, _maxU16),
      url: answer.url?.toString() ?? '',
      headers: answer.headers,
      body: answer.bytes,
      retryAfterSec: answer.retryAfterSec == null
          ? null
          : _clamp(answer.retryAfterSec!, _maxU32),
      sends: _clamp(answer.sends, _maxU32),
    );

/// Answers one script `fetch` through [fetch]. A fetcher that throws, or a
/// URL that does not parse, never reaches the job as an error: it is answered
/// as a failed fetch, so the script sees a normal failure.
@visibleForTesting
Future<native.PluginFetchResponse> answerFetch(
  PluginFetcher fetch,
  native.PluginFetchRequest request,
) async {
  final call = fetchCallFromNative(request);
  if (call == null) {
    return fetchResponseToNative(
      PluginFetchAnswer.failure(PluginFetchOutcome.invalidRequest, sends: 0),
    );
  }
  try {
    final answer = await fetch(call);
    // An ok answer without a final URL means no redirect happened.
    return fetchResponseToNative(
      answer.outcome == PluginFetchOutcome.ok && answer.url == null
          ? PluginFetchAnswer(
              outcome: answer.outcome,
              status: answer.status,
              url: call.url,
              headers: answer.headers,
              bytes: answer.bytes,
              retryAfterSec: answer.retryAfterSec,
              sends: answer.sends,
            )
          : answer,
    );
  } catch (error, stackTrace) {
    // Type only: the text may carry the URL, which can hold secrets.
    _log.warning(
      'Plugin fetcher failed: ${error.runtimeType}',
      null,
      stackTrace,
    );
    return fetchResponseToNative(
      PluginFetchAnswer.failure(PluginFetchOutcome.network),
    );
  }
}

int _clamp(int value, int max) => value < 0 ? 0 : (value > max ? max : value);
