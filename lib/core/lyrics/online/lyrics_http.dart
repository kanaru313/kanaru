import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../app_identity.dart';
import '../../logging/app_logging.dart';
import '../plugins/plugin_run_deadline.dart' show pluginScriptWallTime;
import '../../lyrics_translation/translation_http.dart'
    show translationRequestTimeout;
import 'lyrics_fetch_exception.dart';
import 'lyrics_http_request.dart';
import 'lyrics_http_retry.dart';
import 'lyrics_http_send_loop.dart';
import 'lyrics_provider_registry.dart';
import 'plugin_host_patterns.dart';

export 'lyrics_http_request.dart';

/// What came back: the HTTP `status`, the decoded `body` and the response
/// `headers` (lower-case names).
typedef LyricsHttpResponse = ({
  int status,
  String body,
  Map<String, String> headers,
});

/// The only way a [LyricsProvider] reaches the network. The host builds one
/// from a provider's registration, so a provider cannot reach a host it did
/// not register.
///
/// GET ([get]) or GET and POST ([send], plugin sources), `https`
/// only, no explicit port, no user info, to a host the [PluginHostSet] of
/// the registered hosts allows (a plain name, or one label under a `*.`
/// wildcard a source plugin listed); a request to anything else fails
/// with `blockedHost` before a socket is opened. Timeouts
/// are 10 s to connect and 20 s per send, and 30 s for the whole call with
/// its waits (then `network`); the body is at most 4 MiB
/// ([lyricsMaxResponseBytes]), redirects are not followed. A request that was
/// sent always runs to completion; there is no way to cancel it.
///
/// A 429 or 503 that asks for at most 5 s (a 503 without `Retry-After` asks
/// for 1 s) is waited out and sent again, at most twice, one request at a
/// time; the last answer is returned as it is. `abandoned` is asked before
/// every send, the first one and each retry: when it is true,
/// [LyricsRequestAbandoned] is thrown and nothing is sent. Then `allowed`
/// (the user's consent) is asked; when it is false,
/// `LyricsFetchException(notConsented)` is thrown and nothing is sent.
///
/// The `User-Agent` of [get] is always the one naming the app and its
/// repository; [send] uses the source's when it sets a non-blank one, else
/// the app's. The address and query are never logged.
class LyricsHttp {
  LyricsHttp(
    LyricsProviderRegistration registration,
    HttpClient client, {
    LyricsSleep sleep = realLyricsSleep,
    bool Function()? abandoned,
    bool Function()? allowed,
  }) : this._(
         client,
         registration.hosts,
         strict: true,
         sleep: sleep,
         abandoned: abandoned,
         allowed: allowed,
         maxRetries: maxShortRetries,
         overallTimeout: lyricsOverallTimeout,
       );

  /// For a translate plugin: the strict rules of the main constructor over
  /// the plugin's own [hosts], no retry of a busy answer (the script decides,
  /// and every send counts toward its budget) and no cap per send: a send is
  /// bound only by the time left of the call, which is the `deadline` the
  /// runtime reports for each `fetch` and at most [overallTimeout] (the
  /// longest wall time a translate script may have).
  /// [allowed] is the translate consent, asked before every send.
  LyricsHttp.forPluginTranslate(
    Iterable<String> hosts,
    HttpClient client, {
    required Duration overallTimeout,
    bool Function()? allowed,
    LyricsSleep sleep = realLyricsSleep,
  }) : this._(
         client,
         hosts,
         strict: true,
         sleep: sleep,
         abandoned: null,
         allowed: allowed,
         maxRetries: 0,
         overallTimeout: overallTimeout,
         perSendCap: null,
       );

  /// For a source plugin: the strict rules of the main constructor over the
  /// plugin's own [hosts] (its `*.` wildcards included), no retry of a busy
  /// answer and no cap per send: a send is bound only by the time left of the
  /// call, at most [pluginScriptWallTime] (the wall time of a source
  /// script). [allowed] is the plugin's consent and [abandoned] tells that
  /// the caller no longer wants the answer (a newer search started); both
  /// are asked before every send.
  LyricsHttp.forPluginSource(
    Iterable<String> hosts,
    HttpClient client, {
    bool Function()? allowed,
    bool Function()? abandoned,
    LyricsSleep sleep = realLyricsSleep,
  }) : this._(
         client,
         hosts,
         strict: true,
         sleep: sleep,
         abandoned: abandoned,
         allowed: allowed,
         maxRetries: 0,
         overallTimeout: pluginScriptWallTime,
         perSendCap: null,
       );

  /// For tests: allows `http`, a port and any host in [hosts], so a loopback
  /// server can stand in for the service.
  @visibleForTesting
  LyricsHttp.forTesting({
    required HttpClient client,
    required Iterable<String> hosts,
    LyricsSleep sleep = realLyricsSleep,
    bool Function()? abandoned,
    bool Function()? allowed,
    int maxRetries = maxShortRetries,
    Duration overallTimeout = lyricsOverallTimeout,
    Duration? perSendCap = translationRequestTimeout,
  }) : this._(
         client,
         hosts,
         strict: false,
         sleep: sleep,
         abandoned: abandoned,
         allowed: allowed,
         maxRetries: maxRetries,
         overallTimeout: overallTimeout,
         perSendCap: perSendCap,
       );

  LyricsHttp._(
    HttpClient client,
    Iterable<String> hosts, {
    required this._strict,
    required LyricsSleep sleep,
    required bool Function()? abandoned,
    required bool Function()? allowed,
    required int maxRetries,
    required this._overallTimeout,
    Duration? perSendCap = translationRequestTimeout,
  }) : _hosts = PluginHostSet(hosts),
       _loop = LyricsSendLoop(
         client: client,
         sleep: sleep,
         abandoned: abandoned,
         allowed: allowed,
         maxRetries: maxRetries,
         perSendCap: perSendCap,
       );

  final PluginHostSet _hosts;
  final bool _strict;
  final Duration _overallTimeout;
  final LyricsSendLoop _loop;

  static const _userAgent = 'Kanaru/$kanaruVersion (+$kanaruRepositoryUrl)';

  /// Sends GET [uri] and returns the answer whatever its status. Throws a
  /// [LyricsFetchException]: `blockedHost` for an address that is not
  /// allowed, `notConsented` when consent is gone before a send or by the
  /// time the answer arrives, `network`
  /// for a failed connection or timeout (`rateLimited` with its
  /// `Retry-After` when the last answer before the timeout was a 429 or
  /// 503), `invalidResponse` for a body over 4 MiB or not UTF-8.
  Future<LyricsHttpResponse> get(Uri uri) async {
    if (!_allows(uri)) {
      throw const LyricsFetchException(LyricsFetchKind.blockedHost);
    }
    final result = await _loop.run(
      method: 'GET',
      uri: uri,
      headers: const {'user-agent': _userAgent, 'accept': 'application/json'},
      timeout: _overallTimeout,
    );
    final response = result.response;
    return (
      status: response.status,
      body: response.body,
      headers: response.headers,
    );
  }

  /// Sends [request] for a plugin source and returns the raw answer whatever
  /// its status. The rules of [get] apply (address, consent, retries, the
  /// overall timeout and abandon), with these differences: the method is GET
  /// or POST, the source's headers are filtered by [lyricsRequestHeaders]
  /// (the `User-Agent` is the source's when it sets a non-blank one, else the
  /// app's), the body is sent as given, the bytes are not decoded, and the
  /// whole call ends at the smaller of `request.deadline` and the overall
  /// timeout (a socket still open then is closed too).
  ///
  /// [onSend] is called right before every actual send, retries included, so
  /// the caller can count sends even when the call fails.
  ///
  /// A malformed request throws [LyricsRequestRejected] before anything is
  /// sent. Otherwise the failures are those of [get], except that bytes need
  /// not be UTF-8.
  Future<LyricsHttpRawResponse> send(
    LyricsHttpRequest request, {
    void Function()? onSend,
  }) async {
    final method = checkLyricsRequest(request);
    // A copy, so the caller cannot change the bytes during a busy wait.
    final source = request.body;
    final body = source == null ? null : Uint8List.fromList(source);
    final headers = lyricsRequestHeaders(request.headers);
    final agent = headers['user-agent'];
    if (agent == null || agent.trim().isEmpty) {
      headers['user-agent'] = _userAgent;
    }
    if (!_allows(request.uri)) {
      throw const LyricsFetchException(LyricsFetchKind.blockedHost);
    }
    final deadline = request.deadline;
    var timeout = _overallTimeout;
    if (deadline != null && deadline < timeout) timeout = deadline;
    if (timeout <= Duration.zero) {
      // No time left: nothing goes out.
      _loop.checkAbandoned();
      _loop.checkAllowed();
      throw const LyricsFetchException(LyricsFetchKind.network);
    }
    final result = await _loop.run(
      method: method,
      uri: request.uri,
      headers: headers,
      body: body,
      decode: false,
      timeout: timeout,
      onSend: onSend,
      boundRequests: true,
      maxSends: request.maxSends,
    );
    final response = result.response;
    return LyricsHttpRawResponse(
      status: response.status,
      bytes: response.bytes,
      headers: response.headers,
      url: request.uri,
      sends: result.sends,
    );
  }

  bool _allows(Uri uri) {
    if (!_hosts.allows(uri.host)) return false;
    if (!_strict) return true;
    return uri.scheme == 'https' && !uri.hasPort && uri.userInfo.isEmpty;
  }
}
