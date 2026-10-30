import 'repo_address_rules.dart';

/// Why a repository fetch failed. Core holds no UI text: the app maps a kind
/// (plus the [RepoFetchException.reason]) to a message.
enum RepoFetchErrorKind {
  /// No connection, TLS failure (an untrusted certificate included), timeout,
  /// too many redirects or an HTTP error other than "not found".
  network,

  /// The server answered 404 or 410.
  notFound,

  /// The body is over its cap (catalog, zip or icon).
  tooLarge,

  /// The catalog is not JSON, has the wrong shape, too many entries, or no
  /// usable entry at all.
  invalidCatalog,

  /// The address broke the address rules; [RepoFetchException.reason] says
  /// which rule. Nothing was sent to the refused address.
  blockedAddress,
}

/// A failed repository fetch. Carries no address, header or body, so it is
/// safe to log.
class RepoFetchException implements Exception {
  const RepoFetchException(this.kind, {this.reason});

  final RepoFetchErrorKind kind;

  /// Set for [RepoFetchErrorKind.blockedAddress].
  final RepoAddressProblem? reason;

  @override
  String toString() =>
      'RepoFetchException(${kind.name}${reason == null ? '' : ', ${reason!.name}'})';
}
