import 'dart:io';
import 'dart:typed_data';

import 'repo_address_rules.dart';
import 'repo_fetch_exception.dart';

/// The per-call state shared with the pinned connection: the kind of the
/// catalog and whether the call was cancelled (its total time ran out).
class RepoHopGuard {
  RepoHopGuard(this.kind);

  /// The class of the catalog the fetched URLs belong to. For a catalog fetch
  /// it starts unknown and is decided by the hops. For every fetch (catalog,
  /// zip, icon) it becomes `public` once any hop is public, so a local
  /// address that redirects to a public host does not keep local privileges,
  /// and a public host cannot send the request on to the local network.
  RepoAddressKind? kind;
  bool _cancelled = false;

  bool get cancelled => _cancelled;

  /// Stops the call: no further connection may start.
  void cancel() => _cancelled = true;

  /// Throws when the call was cancelled. Called before every step that would
  /// start work.
  void ensureActive() {
    if (_cancelled) throw const RepoFetchException(RepoFetchErrorKind.network);
  }

  /// Runs inside the pinned connection on the one answer it will connect to.
  void check(Uri url, List<InternetAddress> addresses) {
    ensureActive();
    final verdict = judgeRepoAddress(
      url,
      addresses: addresses,
      catalogKind: kind,
    );
    if (!verdict.isAllowed) {
      throw RepoFetchException(
        RepoFetchErrorKind.blockedAddress,
        reason: verdict.problem,
      );
    }
    if (verdict.kind == RepoAddressKind.public) {
      kind = RepoAddressKind.public;
    } else {
      kind ??= verdict.kind;
    }
  }
}

/// Closes the connection without reading the body.
Future<void> discardRepoResponse(HttpClientResponse response) async {
  final sub = response.listen((_) {}, onError: (_) {});
  await sub.cancel();
}

/// Reads the body; stops (and closes the connection) once [maxBytes] is
/// passed, by the declared length or by the bytes received.
Future<Uint8List> readCappedRepoBody(
  HttpClientResponse response,
  int maxBytes,
  RepoHopGuard guard,
) async {
  if (response.contentLength > maxBytes) {
    await discardRepoResponse(response);
    throw const RepoFetchException(RepoFetchErrorKind.tooLarge);
  }
  final out = BytesBuilder(copy: false);
  // Leaving the loop cancels the subscription and closes the connection.
  await for (final chunk in response) {
    guard.ensureActive();
    out.add(chunk);
    if (out.length > maxBytes) {
      throw const RepoFetchException(RepoFetchErrorKind.tooLarge);
    }
  }
  return out.takeBytes();
}

RepoFetchException asRepoFetchException(Object error) {
  if (error is RepoFetchException) return error;
  // Socket, TLS, HTTP, timeout, closed client and anything else: the text of
  // the original may name the address, so it is dropped.
  return const RepoFetchException(RepoFetchErrorKind.network);
}
