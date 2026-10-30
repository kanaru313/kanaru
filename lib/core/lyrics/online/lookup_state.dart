import 'lyrics_fetch_exception.dart';

/// Where the lookup of one metadata key stands. A finished lookup leaves no
/// entry: its answer is in the cache.
sealed class LookupState {
  const LookupState();
}

/// A request is in flight at [providerId].
final class LookupRunning extends LookupState {
  const LookupRunning({required this.providerId, required this.auto});

  final String providerId;

  /// Kanaru started it, not the user.
  final bool auto;
}

/// The last lookup failed and wrote nothing. [kind] is `null` for a failure
/// that is not a request error (e.g. the database).
final class LookupFailed extends LookupState {
  const LookupFailed(this.kind);

  final LyricsFetchKind? kind;
}
