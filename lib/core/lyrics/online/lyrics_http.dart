import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../app_identity.dart';
import '../../logging/app_logging.dart';
import '../../lyrics_translation/translation_failure.dart';
import '../../lyrics_translation/translation_http.dart';
import 'lyrics_fetch_exception.dart';
import 'lyrics_http_retry.dart';
import 'lyrics_provider_registry.dart';

/// What came back: the HTTP `status`, the decoded `body` and the response
/// `headers` (lower-case names).
typedef LyricsHttpResponse = ({
  int status,
  String body,
  Map<String, String> headers,
});

/// Largest lyrics response body read, in bytes.
const lyricsMaxResponseBytes = 4 * 1024 * 1024;

/// The only way a [LyricsProvider] reaches the network. The host builds one
/// from a provider's registration, so a provider cannot reach a host it did
/// not register.
///
/// GET only, `https` only, no explicit port, no user info; a request to
/// anything else fails with `blockedHost` before a socket is opened. Timeouts
/// are 10 s to connect and 20 s per send, and 30 s for the whole call with
/// its waits (then `network`); the body is at most 4 MiB
/// ([lyricsMaxResponseBytes]), redirects are not followed. A request that was
/// sent always runs to completion; there is no way to cancel it.
///
/// A 429 or 503 that asks for at most 5 s (a 503 without `Retry-After` asks
/// for 1 s) is waited out and sent again, at most twice, one request at a
/// time; the last answer is returned as it is. If `abandoned` turns true
/// during a wait, [LyricsRequestAbandoned] is thrown instead of the next
/// send. `allowed` (the user's consent) is asked before every send, the
/// first one and each retry; when it is false,
/// `LyricsFetchException(notConsented)` is thrown and nothing is sent.
///
/// Only a `User-Agent` naming the app and its repository is sent. The
/// address and query are never logged.
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
  }) : this._(
         client,
         hosts,
         strict: false,
         sleep: sleep,
         abandoned: abandoned,
         allowed: allowed,
         maxRetries: maxRetries,
         overallTimeout: overallTimeout,
       );

  LyricsHttp._(
    this._client,
    Iterable<String> hosts, {
    required this._strict,
    required this._sleep,
    required this._abandoned,
    required this._allowed,
    required this._maxRetries,
    required this._overallTimeout,
  }) : _hosts = Set.unmodifiable(hosts);

  final HttpClient _client;
  final Set<String> _hosts;
  final bool _strict;
  final LyricsSleep _sleep;
  final bool Function()? _abandoned;
  final bool Function()? _allowed;
  final int _maxRetries;
  final Duration _overallTimeout;

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
    var expired = false;
    LyricsHttpResponse? busy;
    try {
      final response = await _getWithRetries(
        uri,
        () => expired,
        (response) => busy = response,
      ).timeout(_overallTimeout);
      // An answer that arrives after consent was withdrawn is dropped.
      _checkAllowed();
      return response;
    } on TimeoutException {
      expired = true;
      final last = busy;
      if (last == null) {
        throw const LyricsFetchException(LyricsFetchKind.network);
      }
      throw LyricsFetchException(
        LyricsFetchKind.rateLimited,
        retryAfter: parseRetryAfter(last.headers['retry-after']),
      );
    }
  }

  /// Sends [uri] and again after a short busy answer. Once [expired] (the
  /// caller gave up) or the lookup is abandoned, no further send goes out.
  Future<LyricsHttpResponse> _getWithRetries(
    Uri uri,
    bool Function() expired,
    void Function(LyricsHttpResponse) busy,
  ) async {
    bool abandoned() => _abandoned?.call() ?? false;
    for (var retries = 0; ; retries++) {
      _checkAllowed();
      final response = await _send(uri);
      if (response.status == 429 || response.status == 503) busy(response);
      final wait = retries < _maxRetries
          ? shortRetryWait(response.status, response.headers)
          : null;
      if (wait == null || expired()) return response;
      if (abandoned()) throw const LyricsRequestAbandoned();
      await _sleep(wait);
      if (expired()) return response;
      if (abandoned()) throw const LyricsRequestAbandoned();
    }
  }

  void _checkAllowed() {
    if (!(_allowed?.call() ?? true)) {
      throw const LyricsFetchException(LyricsFetchKind.notConsented);
    }
  }

  Future<LyricsHttpResponse> _send(Uri uri) async {
    try {
      return await sendTranslationRequest(
        _client,
        method: 'GET',
        uri: uri,
        headers: const {'user-agent': _userAgent, 'accept': 'application/json'},
        maxBytes: lyricsMaxResponseBytes,
      );
    } on TranslationException catch (e) {
      throw LyricsFetchException(
        e.kind == TranslationFailureKind.network
            ? LyricsFetchKind.network
            : LyricsFetchKind.invalidResponse,
      );
    }
  }

  bool _allows(Uri uri) {
    if (uri.host.isEmpty || !_hosts.contains(uri.host)) return false;
    if (!_strict) return true;
    return uri.scheme == 'https' && !uri.hasPort && uri.userInfo.isEmpty;
  }
}
