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

/// The only way a [LyricsProvider] reaches the network. The host builds one
/// from a provider's registration, so a provider cannot reach a host it did
/// not register.
///
/// GET only, `https` only, no explicit port, no user info; a request to
/// anything else fails with `blockedHost` before a socket is opened. Timeouts
/// are 10 s to connect and 20 s per send, and 30 s for the whole call with
/// its waits (then `network`); the body is at most 2 MiB, redirects are not
/// followed. A request that was sent always runs to completion;
/// there is no way to cancel it.
///
/// A 429 or 503 that asks for at most 5 s (a 503 without `Retry-After` asks
/// for 1 s) is waited out and sent again, at most twice, one request at a
/// time; the last answer is returned as it is. If `abandoned` turns true
/// during a wait, [LyricsRequestAbandoned] is thrown instead of the next
/// send.
///
/// Only a `User-Agent` naming the app and its repository is sent. The
/// address and query are never logged.
class LyricsHttp {
  LyricsHttp(
    LyricsProviderRegistration registration,
    HttpClient client, {
    LyricsSleep sleep = realLyricsSleep,
    bool Function()? abandoned,
  }) : this._(
         client,
         registration.hosts,
         strict: true,
         sleep: sleep,
         abandoned: abandoned,
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
    int maxRetries = maxShortRetries,
    Duration overallTimeout = lyricsOverallTimeout,
  }) : this._(
         client,
         hosts,
         strict: false,
         sleep: sleep,
         abandoned: abandoned,
         maxRetries: maxRetries,
         overallTimeout: overallTimeout,
       );

  LyricsHttp._(
    this._client,
    Iterable<String> hosts, {
    required this._strict,
    required this._sleep,
    required this._abandoned,
    required this._maxRetries,
    required this._overallTimeout,
  }) : _hosts = Set.unmodifiable(hosts);

  final HttpClient _client;
  final Set<String> _hosts;
  final bool _strict;
  final LyricsSleep _sleep;
  final bool Function()? _abandoned;
  final int _maxRetries;
  final Duration _overallTimeout;

  static const _userAgent = 'Kanaru/$kanaruVersion (+$kanaruRepositoryUrl)';

  /// Sends GET [uri] and returns the answer whatever its status. Throws a
  /// [LyricsFetchException]: `blockedHost` for an address that is not
  /// allowed, `network` for a failed connection or timeout,
  /// `invalidResponse` for a body over 2 MiB or not UTF-8.
  Future<LyricsHttpResponse> get(Uri uri) async {
    if (!_allows(uri)) {
      throw const LyricsFetchException(LyricsFetchKind.blockedHost);
    }
    var expired = false;
    try {
      return await _getWithRetries(uri, () => expired).timeout(_overallTimeout);
    } on TimeoutException {
      expired = true;
      throw const LyricsFetchException(LyricsFetchKind.network);
    }
  }

  /// Sends [uri] and again after a short busy answer. Once [expired] (the
  /// caller gave up) or the lookup is abandoned, no further send goes out.
  Future<LyricsHttpResponse> _getWithRetries(
    Uri uri,
    bool Function() expired,
  ) async {
    bool abandoned() => _abandoned?.call() ?? false;
    for (var retries = 0; ; retries++) {
      final response = await _send(uri);
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

  Future<LyricsHttpResponse> _send(Uri uri) async {
    try {
      return await sendTranslationRequest(
        _client,
        method: 'GET',
        uri: uri,
        headers: const {'user-agent': _userAgent, 'accept': 'application/json'},
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
