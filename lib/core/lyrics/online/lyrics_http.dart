import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../app_identity.dart';
import '../../logging/app_logging.dart';
import '../../lyrics_translation/translation_failure.dart';
import '../../lyrics_translation/translation_http.dart';
import 'lyrics_fetch_exception.dart';
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
/// are 10 s to connect and 20 s in all, the body is at most 2 MiB, redirects
/// are not followed. A request that was sent always runs to completion;
/// there is no way to cancel it.
///
/// Only a `User-Agent` naming the app and its repository is sent. The
/// address and query are never logged.
class LyricsHttp {
  LyricsHttp(LyricsProviderRegistration registration, HttpClient client)
    : this._(client, registration.hosts, strict: true);

  /// For tests: allows `http`, a port and any host in [hosts], so a loopback
  /// server can stand in for the service.
  @visibleForTesting
  LyricsHttp.forTesting({
    required HttpClient client,
    required Iterable<String> hosts,
  }) : this._(client, hosts, strict: false);

  LyricsHttp._(this._client, Iterable<String> hosts, {required this._strict})
    : _hosts = Set.unmodifiable(hosts);

  final HttpClient _client;
  final Set<String> _hosts;
  final bool _strict;

  static const _userAgent = 'Kanaru/$kanaruVersion (+$kanaruRepositoryUrl)';

  /// Sends GET [uri] and returns the answer whatever its status. Throws a
  /// [LyricsFetchException]: `blockedHost` for an address that is not
  /// allowed, `network` for a failed connection or timeout,
  /// `invalidResponse` for a body over 2 MiB or not UTF-8.
  Future<LyricsHttpResponse> get(Uri uri) async {
    if (!_allows(uri)) {
      throw const LyricsFetchException(LyricsFetchKind.blockedHost);
    }
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
