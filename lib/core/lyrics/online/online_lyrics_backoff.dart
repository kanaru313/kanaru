import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lyrics_fetch_exception.dart';

/// Shortest pause after a failed lookup.
const minBackoff = Duration(seconds: 60);

/// Largest share of the wait added at random, so clients do not retry in step.
const maxBackoffJitter = 0.3;

/// Time source of the lookup code; tests replace it.
final onlineLyricsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Randomness of the backoff, a value in 0..1; tests replace it.
final onlineLyricsRandomProvider = Provider<double Function()>(
  (ref) => Random().nextDouble,
);

/// How long a song stays on screen before an automatic lookup starts, so
/// skipping through a queue sends nothing.
final onlineLyricsDebounceProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 1),
);

/// Session pause of automatic lookups after a failure. The state is the
/// moment the pause ends (`null` for none); it lives in memory only and is
/// fed by failed lookups, never by a missing consent.
class OnlineLyricsBackoff extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Pauses until now plus [minBackoff], or the wait the service asked for
  /// (clamped to [minRetryAfter]..[maxRetryAfter]) when that is longer, plus
  /// up to [maxBackoffJitter] of it. A pause never gets shorter.
  void failed([Duration? retryAfter]) {
    var wait = minBackoff;
    if (retryAfter != null) {
      final asked = retryAfter < minRetryAfter
          ? minRetryAfter
          : (retryAfter > maxRetryAfter ? maxRetryAfter : retryAfter);
      if (asked > wait) wait = asked;
    }
    final jitter = ref.read(onlineLyricsRandomProvider)().clamp(0.0, 1.0);
    final until = ref
        .read(onlineLyricsClockProvider)()
        .add(wait + wait * (jitter * maxBackoffJitter));
    final current = state;
    if (current == null || until.isAfter(current)) state = until;
  }

  /// Ends the pause (Retry, Search again).
  void clear() => state = null;

  /// Whether the pause is still running.
  bool get isBlocked {
    final until = state;
    return until != null &&
        ref.read(onlineLyricsClockProvider)().isBefore(until);
  }
}

final onlineLyricsBackoffProvider =
    NotifierProvider<OnlineLyricsBackoff, DateTime?>(OnlineLyricsBackoff.new);
