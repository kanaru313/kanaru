import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../../app_identity.dart';
import '../../../logging/app_logging.dart';
import '../../../database/lyrics_plugin_spec.dart';
import '../../online/lyrics_http_pinned_connect.dart';
import '../package/plugin_package_limits.dart';
import 'repo_address_rules.dart';
import 'repo_fetch_exception.dart';
import 'repo_http_support.dart';

/// Body caps. Reading stops as soon as one is passed.
const repoCatalogMaxBytes = lyricsPluginCatalogMaxBytes;
const repoZipMaxBytes = maxPluginPackageBytes;
const repoIconMaxBytes = maxPluginIconBytes;

/// At most this many redirects are followed; the next one is refused.
const repoMaxRedirects = 3;

const repoConnectTimeout = Duration(seconds: 10);
const repoTotalTimeout = Duration(seconds: 20);

const _userAgent = 'Kanaru/$kanaruVersion (+$kanaruRepositoryUrl)';

/// A fetched body. [finalUrl] is where it came from after redirects (relative
/// references in a catalog are resolved against it) and [kind] the class of
/// the catalog it belongs to.
class RepoResponse {
  const RepoResponse({
    required this.bytes,
    required this.finalUrl,
    required this.kind,
  });

  final Uint8List bytes;
  final Uri finalUrl;
  final RepoAddressKind kind;
}

/// The only way the plugin repository feature reaches the network: GET of a
/// catalog, a plugin zip or an icon. Not [LyricsHttp]: this is not a lyrics
/// source, sends no song data and is not gated by lyrics consent.
///
/// Every connection is pinned: the host is resolved once, every resolved
/// address is judged by [judgeRepoAddress] and the socket goes to those
/// addresses only (see [lyricsPinnedConnectionFactory]), TLS verifies the
/// original host name, and there is no bad-certificate callback. Redirects
/// are followed by hand, at most [repoMaxRedirects]; each hop is judged again
/// with the kind of the repository's catalog, which narrows to public once
/// any hop is public, so neither a public catalog nor a public host in the
/// middle of a chain can redirect into the local network. Every hop uses a fresh connection, so the
/// check cannot be skipped by a reused keep-alive socket. The whole call
/// (all hops) is limited to [repoTotalTimeout]. Proxies are not used: the
/// destination must be checked here, not by a proxy.
///
/// Failures are [RepoFetchException]s; nothing else escapes.
class RepoHttp {
  RepoHttp({
    this._resolver = systemLyricsHostResolver,
    this._securityContext,
    this._dialer,
    this._connectTimeout = repoConnectTimeout,
    this._totalTimeout = repoTotalTimeout,
  });

  final LyricsHostResolver _resolver;
  final SecurityContext? _securityContext;
  final LyricsSocketDialer? _dialer;
  final Duration _connectTimeout;
  final Duration _totalTimeout;

  /// Fetches the catalog the user typed at [url]. The class of its address
  /// becomes [RepoResponse.kind] for everything the catalog points to.
  Future<RepoResponse> fetchCatalog(Uri url) =>
      _get(url, null, repoCatalogMaxBytes);

  /// Fetches a plugin zip that a catalog of [catalogKind] points to.
  Future<RepoResponse> fetchZip(
    Uri url, {
    required RepoAddressKind catalogKind,
  }) => _get(url, catalogKind, repoZipMaxBytes);

  /// Fetches an icon that a catalog of [catalogKind] points to. The bytes are
  /// not checked here; see `fetchCatalogIcon`.
  Future<RepoResponse> fetchIcon(
    Uri url, {
    required RepoAddressKind catalogKind,
  }) => _get(url, catalogKind, repoIconMaxBytes);

  /// The class a zip or icon of the repository at [repoUrl] must obey now:
  /// the stricter of [stored] (the class at the last good fetch, which holds
  /// the redirect narrowing) and a fresh look at the repository URL with this
  /// client's resolver, so a name that has since started to resolve elsewhere
  /// is noticed. Fails closed, never falling back to [stored]: a failed
  /// lookup is `network` and a refused address is `blockedAddress`.
  ///
  /// An IP literal or a local-looking name (`.lan`) counts as local on any
  /// network; there is no way to tell a foreign network from the user's own.
  Future<RepoAddressKind> effectiveKind(
    Uri repoUrl,
    RepoAddressKind stored,
  ) async {
    final RepoAddressVerdict verdict;
    try {
      verdict = await checkRepoAddress(
        repoUrl,
        resolver: _resolver,
        lookupTimeout: _connectTimeout,
      );
    } on Object {
      throw const RepoFetchException(RepoFetchErrorKind.network);
    }
    if (!verdict.isAllowed) {
      throw RepoFetchException(
        RepoFetchErrorKind.blockedAddress,
        reason: verdict.problem,
      );
    }
    return stored == RepoAddressKind.public ||
            verdict.kind == RepoAddressKind.public
        ? RepoAddressKind.public
        : RepoAddressKind.local;
  }

  Future<RepoResponse> _get(
    Uri url,
    RepoAddressKind? catalogKind,
    int maxBytes,
  ) {
    final client = HttpClient()
      ..connectionTimeout = _connectTimeout
      ..userAgent = _userAgent
      ..findProxy = ((_) => 'DIRECT');
    final guard = RepoHopGuard(catalogKind);
    client.connectionFactory = lyricsPinnedConnectionFactory(
      check: guard.check,
      resolver: _resolver,
      dialer: _dialer ?? (a, p) => Socket.startConnect(a, p),
      context: _securityContext,
      connectTimeout: _connectTimeout,
    );
    return _follow(client, url, guard, maxBytes)
        .timeout(
          _totalTimeout,
          onTimeout: () {
            // The work must stop, not just the wait: nothing new may start
            // and sockets in flight are destroyed.
            guard.cancel();
            client.close(force: true);
            throw const RepoFetchException(RepoFetchErrorKind.network);
          },
        )
        .then<RepoResponse>(
          (r) => r,
          onError: (Object e) => throw asRepoFetchException(e),
        )
        .whenComplete(() {
          guard.cancel();
          client.close(force: true);
        });
  }

  Future<RepoResponse> _follow(
    HttpClient client,
    Uri start,
    RepoHopGuard hops,
    int maxBytes,
  ) async {
    var url = start;
    for (var redirects = 0; ; redirects++) {
      // Shape and name rules first, so a bad URL never reaches the resolver.
      final shape = judgeRepoAddress(url, catalogKind: hops.kind);
      if (!shape.isAllowed) {
        throw RepoFetchException(
          RepoFetchErrorKind.blockedAddress,
          reason: shape.problem,
        );
      }
      hops.ensureActive();
      final request = await client.getUrl(url);
      request
        ..followRedirects = false
        ..persistentConnection = false;
      final response = await request.close();
      hops.ensureActive();
      final status = response.statusCode;
      if (status >= 300 && status < 400) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await discardRepoResponse(response);
        if (location == null || redirects >= repoMaxRedirects) {
          throw const RepoFetchException(RepoFetchErrorKind.network);
        }
        final next = Uri.tryParse(location);
        if (next == null) {
          throw const RepoFetchException(RepoFetchErrorKind.network);
        }
        url = url.resolveUri(next);
        continue;
      }
      if (status == 404 || status == 410) {
        await discardRepoResponse(response);
        throw const RepoFetchException(RepoFetchErrorKind.notFound);
      }
      if (status < 200 || status >= 300) {
        await discardRepoResponse(response);
        throw const RepoFetchException(RepoFetchErrorKind.network);
      }
      final bytes = await readCappedRepoBody(response, maxBytes, hops);
      return RepoResponse(
        bytes: bytes,
        finalUrl: url,
        kind: hops.kind ?? RepoAddressKind.public,
      );
    }
  }
}
