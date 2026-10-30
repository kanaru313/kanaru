import 'dart:typed_data';

/// One `fetch` of a plugin script, handed to the app's [PluginFetcher].
class PluginFetchCall {
  const PluginFetchCall({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
    required this.deadline,
    required this.maxSends,
  });

  /// `GET` or `POST`.
  final String method;

  /// The script's URL with its queries already appended and encoded.
  final Uri url;
  final List<(String, String)> headers;
  final Uint8List body;

  /// What is left of the call's time. The fetcher should give up (answer
  /// [PluginFetchOutcome.network]) when it passes; the runtime cuts the wait
  /// at that moment anyway.
  final Duration deadline;

  /// HTTP sends still allowed for this call (retries included), at least 1.
  /// An answer that reports more is counted as this value.
  final int maxSends;
}

/// How the app answered a [PluginFetchCall].
enum PluginFetchOutcome {
  /// A response arrived; status, url, headers and bytes are set.
  ok,

  /// Connection, TLS, timeout or similar.
  network,

  /// The host is not on the plugin's allowlist.
  blockedHost,

  /// The user has not allowed this plugin to use the network.
  notConsented,

  /// The user stopped the lookup; the run ends cancelled.
  abandoned,

  /// The app refused the request (method, header or body).
  invalidRequest,

  /// The app refused the answer (for example a body over 4 MiB).
  invalidResponse,

  /// The server asked to slow down; see [PluginFetchAnswer.retryAfterSec].
  rateLimited,
}

/// The app's answer to a [PluginFetchCall].
class PluginFetchAnswer {
  PluginFetchAnswer({
    required this.outcome,
    this.status = 0,
    this.url,
    this.headers = const [],
    Uint8List? bytes,
    this.retryAfterSec,
    this.sends = 0,
  }) : bytes = bytes ?? Uint8List(0);

  /// A failed answer without a response.
  PluginFetchAnswer.failure(
    PluginFetchOutcome outcome, {
    int? retryAfterSec,
    int sends = 0,
  }) : this(outcome: outcome, retryAfterSec: retryAfterSec, sends: sends);

  final PluginFetchOutcome outcome;

  /// HTTP status; only read when [outcome] is [PluginFetchOutcome.ok].
  final int status;

  /// The final URL after redirects.
  final Uri? url;
  final List<(String, String)> headers;
  final Uint8List bytes;

  /// For [PluginFetchOutcome.rateLimited]: the server's `Retry-After`.
  final int? retryAfterSec;

  /// HTTP sends made for this call, retries counted. 0 when none went out
  /// (a refused request); the runtime counts at least 1 for an ok, network,
  /// rate-limited or invalid-response answer.
  final int sends;
}

/// Answers the `fetch` calls of a running plugin. Must not throw; if it does,
/// the runtime answers [PluginFetchOutcome.network].
typedef PluginFetcher = Future<PluginFetchAnswer> Function(
  PluginFetchCall call,
);
