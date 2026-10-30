import 'dart:async';
import 'dart:io';

import '../../online/lyrics_http_address_class.dart';
import '../../online/lyrics_http_pinned_connect.dart';

/// Where a repository lives, which decides what its catalog may point to.
enum RepoAddressKind {
  /// The catalog resolves to the user's own machine or network.
  local,

  /// The catalog resolves to the public internet.
  public,
}

/// Which address rule an address broke. The app maps each value to text; the
/// public-without-https case reads "Địa chỉ công khai cần https".
enum RepoAddressProblem {
  /// Not an absolute `http` or `https` URL with a host.
  invalidUrl,

  /// The URL carries a user name or password.
  userInfo,

  /// A public destination over plain `http`.
  publicNeedsHttps,

  /// A public catalog points at a local address.
  localFromPublic,

  /// The name resolves to an address no one may reach (unspecified,
  /// multicast, broadcast, documentation, reserved ranges).
  refusedAddress,

  /// The name resolves to addresses of different classes.
  mixedAddresses,

  /// A local-looking name (`nas.lan`, `localhost`) resolves to a public
  /// address, which is not what the name promises.
  localNameOnPublic,
}

/// The outcome of one check: [problem] is null when the address is allowed.
/// [kind] is the class of the destination; null when the host was not
/// resolved and so could not be told.
class RepoAddressVerdict {
  const RepoAddressVerdict.allowed(this.kind) : problem = null;
  const RepoAddressVerdict.refused(this.problem) : kind = null;

  final RepoAddressKind? kind;
  final RepoAddressProblem? problem;

  bool get isAllowed => problem == null;
}

/// Decides whether [url] may be fetched, from what its host resolved to
/// ([addresses], or null when the host was not resolved yet: then only the
/// rules that do not depend on the answer are applied).
///
/// [catalogKind] is the kind of the catalog the URL was taken from, or null
/// when [url] is the repository URL the user typed. Rules, by who chose the
/// host:
///
/// * The repository URL (user typed): `http` or `https`, IP and port allowed;
///   `http` only for a local destination, a public one needs `https`.
/// * A reference inside a catalog (`path`, `icon`, each redirect): a public
///   catalog may point only to public `https` addresses, never to a local
///   address or `http`. A local catalog may point to local addresses (any
///   scheme) and to public `https` ones (an outgoing request only, it
///   exposes nothing).
/// * No user info; every resolved address must be of one class (a mixed
///   answer is refused); refused ranges are never allowed; a local name
///   must not resolve to a public address.
RepoAddressVerdict judgeRepoAddress(
  Uri url, {
  List<InternetAddress>? addresses,
  RepoAddressKind? catalogKind,
}) {
  if ((url.scheme != 'http' && url.scheme != 'https') || url.host.isEmpty) {
    return const RepoAddressVerdict.refused(RepoAddressProblem.invalidUrl);
  }
  if (url.userInfo.isNotEmpty) {
    return const RepoAddressVerdict.refused(RepoAddressProblem.userInfo);
  }
  final https = url.scheme == 'https';
  final found = addresses == null
      ? _knownWithoutLookup(url.host)
      : classifyLyricsAddresses(addresses);
  switch (found) {
    case LyricsAddressClass.refused:
      return const RepoAddressVerdict.refused(
        RepoAddressProblem.refusedAddress,
      );
    case LyricsAddressClass.mixed:
      return const RepoAddressVerdict.refused(
        RepoAddressProblem.mixedAddresses,
      );
    case LyricsAddressClass.local:
      if (catalogKind == RepoAddressKind.public) {
        return const RepoAddressVerdict.refused(
          RepoAddressProblem.localFromPublic,
        );
      }
      return const RepoAddressVerdict.allowed(RepoAddressKind.local);
    case LyricsAddressClass.public:
      if (isLocalHostName(url.host)) {
        return const RepoAddressVerdict.refused(
          RepoAddressProblem.localNameOnPublic,
        );
      }
      if (!https) {
        return const RepoAddressVerdict.refused(
          RepoAddressProblem.publicNeedsHttps,
        );
      }
      return const RepoAddressVerdict.allowed(RepoAddressKind.public);
    case null:
      // Not resolved yet and not an IP literal or local name. Only the
      // rule that holds for every answer applies: a public catalog never
      // points to plain `http`.
      if (catalogKind == RepoAddressKind.public && !https) {
        return const RepoAddressVerdict.refused(
          RepoAddressProblem.publicNeedsHttps,
        );
      }
      return const RepoAddressVerdict.allowed(null);
  }
}

/// The class of [host] when it is known without a lookup: an IP literal, or
/// a local-looking name (taken as local). Otherwise null.
LyricsAddressClass? _knownWithoutLookup(String host) {
  final literal = InternetAddress.tryParse(host);
  if (literal != null) return classifyLyricsAddress(literal);
  if (isLocalHostName(host)) return LyricsAddressClass.local;
  return null;
}

/// Resolves the host of [url] (once; an IP literal needs no lookup) and
/// judges it with [judgeRepoAddress]. For checks that are not followed by a
/// connection (the add dialog); a fetch checks inside its pinned connection
/// instead, so the answer it checks is the one it connects to.
///
/// A host that does not resolve, resolves to nothing or takes longer than
/// [lookupTimeout] counts as a network problem and throws a
/// [SocketException]; it is not a refused address.
Future<RepoAddressVerdict> checkRepoAddress(
  Uri url, {
  RepoAddressKind? catalogKind,
  LyricsHostResolver resolver = systemLyricsHostResolver,
  Duration lookupTimeout = const Duration(seconds: 10),
}) async {
  final shape = judgeRepoAddress(url, catalogKind: catalogKind);
  if (shape.problem == RepoAddressProblem.invalidUrl ||
      shape.problem == RepoAddressProblem.userInfo) {
    return shape;
  }
  final literal = InternetAddress.tryParse(url.host);
  final List<InternetAddress> addresses;
  if (literal != null) {
    addresses = [literal];
  } else {
    try {
      addresses = await resolver(url.host).timeout(lookupTimeout);
    } on TimeoutException {
      throw const SocketException('Host lookup timed out');
    }
    if (addresses.isEmpty) {
      throw const SocketException('Host lookup found nothing');
    }
  }
  return judgeRepoAddress(url, addresses: addresses, catalogKind: catalogKind);
}
