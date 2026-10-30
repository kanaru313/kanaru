import 'dart:typed_data';

import '../online/lyrics_fetch_exception.dart';
import '../online/lyrics_http.dart';
import '../online/lyrics_http_retry.dart';
import '../../plugin_runtime/plugin_runtime.dart';

/// What the plugin log keeps of one `fetch`: no query string, no fragment, no
/// header and no body, so no secret can be in it.
class PluginRequestRecord {
  const PluginRequestRecord({
    required this.method,
    required this.host,
    required this.path,
    required this.status,
    required this.ms,
    this.blocked = false,
  });

  final String method;
  final String host;

  /// The path only.
  final String path;

  /// The HTTP status; `null` when no answer came.
  final int? status;

  /// Milliseconds spent in `LyricsHttp.send`, retries and waits included.
  final int ms;

  /// The call failed with `blockedHost`. Not written to the log file; the
  /// app log names the host of such a call.
  final bool blocked;

  Map<String, Object?> toJson() => {
    'method': method,
    'host': host,
    'path': path,
    'status': status,
    'ms': ms,
  };
}

/// Answers the `fetch` calls of one plugin run through a [LyricsHttp]: the
/// same host allowlist, consent, retry and abandon rules as every other
/// source. Make one bridge per run; [requests] holds the run's records once
/// it is over.
///
/// Rules:
/// * [call] never throws and never logs an error's text or a header (a
///   header can hold a secret); a failure becomes an outcome;
/// * `sends` counts the real sends (through `onSend`), so a call that then
///   failed still reports them;
/// * a refused call that sent nothing (blocked host, no consent, bad request,
///   no time left) reports one send. The runtime adds the reported `sends`
///   of every outcome to the run's 10-send budget (it raises only ok,
///   network, rate-limited and invalid-response answers to at least one, and
///   takes the reported number as it is for the others), so a script that
///   loops on refused fetches runs out of budget after ten of them. This was
///   checked in `rust_plugin_runtime.dart` and `host_fetch.rs`.
class PluginFetchBridge {
  PluginFetchBridge(this._http);

  final LyricsHttp _http;
  final _calls = <_Call>[];

  /// One record per call, in call order. A call still waiting (one that hung
  /// until the run timed out) is listed too, with no status and the time it
  /// has waited so far.
  List<PluginRequestRecord> get requests => [
    for (final c in _calls)
      PluginRequestRecord(
        method: c.method,
        host: c.host,
        path: c.path,
        status: c.status,
        ms: c.clock.elapsedMilliseconds,
        blocked: c.blocked,
      ),
  ];

  /// The [PluginFetcher] of the run.
  Future<PluginFetchAnswer> call(PluginFetchCall call) async {
    var sends = 0;
    final record = _Call(call);
    _calls.add(record);
    PluginFetchAnswer answer;
    try {
      final response = await _http.send(
        LyricsHttpRequest(
          method: call.method,
          uri: call.url,
          headers: {for (final (name, value) in call.headers) name: value},
          body: call.body.isEmpty ? null : call.body,
          deadline: call.deadline,
          maxSends: call.maxSends,
        ),
        onSend: () => sends++,
      );
      record.status = response.status;
      answer = PluginFetchAnswer(
        outcome: PluginFetchOutcome.ok,
        status: response.status,
        url: response.url,
        headers: [for (final e in response.headers.entries) (e.key, e.value)],
        bytes: response.bytes,
        sends: response.sends,
      );
    } on LyricsFetchException catch (e) {
      record.blocked = e.kind == LyricsFetchKind.blockedHost;
      answer = _failure(_outcomeOf(e.kind), sends, e.retryAfter);
    } on LyricsRequestRejected {
      answer = _failure(PluginFetchOutcome.invalidRequest, sends);
    } on LyricsRequestAbandoned {
      answer = _failure(PluginFetchOutcome.abandoned, sends);
    } on Object {
      // Anything else is a network failure; the error text is dropped.
      answer = _failure(PluginFetchOutcome.network, sends);
    }
    record.clock.stop();
    return answer;
  }

  // A failed answer counts at least one send (see the class comment).
  PluginFetchAnswer _failure(
    PluginFetchOutcome outcome,
    int sends, [
    Duration? retryAfter,
  ]) => PluginFetchAnswer(
    outcome: outcome,
    bytes: Uint8List(0),
    retryAfterSec: outcome == PluginFetchOutcome.rateLimited
        ? retryAfter?.inSeconds
        : null,
    sends: sends < 1 ? 1 : sends,
  );

  PluginFetchOutcome _outcomeOf(LyricsFetchKind kind) => switch (kind) {
    LyricsFetchKind.network ||
    LyricsFetchKind.server => PluginFetchOutcome.network,
    LyricsFetchKind.rateLimited => PluginFetchOutcome.rateLimited,
    LyricsFetchKind.invalidResponse => PluginFetchOutcome.invalidResponse,
    LyricsFetchKind.blockedHost => PluginFetchOutcome.blockedHost,
    LyricsFetchKind.notConsented => PluginFetchOutcome.notConsented,
  };
}

/// A call in progress or finished; its clock runs until the answer is back.
class _Call {
  _Call(PluginFetchCall call)
    : method = call.method.toUpperCase(),
      host = call.url.host,
      path = call.url.path;

  final String method;
  final String host;
  final String path;
  final clock = Stopwatch()..start();
  int? status;
  bool blocked = false;
}
