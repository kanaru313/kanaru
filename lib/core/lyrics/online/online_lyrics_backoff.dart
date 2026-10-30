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

/// How long an automatic lookup waits before it asks again for a song where a
/// source was left unasked without a failure (the plugin runtime had every
/// worker busy). Without it the song would be retried once per debounce for
/// as long as the runtime stays busy. A new song starts its own lookup at
/// once.
final onlineLyricsSkipRetryProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
);

/// Session pause of automatic lookups after a failure, kept per source. The
/// state maps a provider id to the moment its pause ends; an entry whose time
/// has passed is as good as none. It lives in memory only and is fed by failed
/// lookups, never by a missing consent. A failing source pauses only itself,
/// so the others keep looking songs up.
class OnlineLyricsBackoff extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => const {};

  /// Pauses [providerId] until now plus [minBackoff], or the wait the service
  /// asked for (clamped to [minRetryAfter]..[maxRetryAfter]) when that is
  /// longer, plus up to [maxBackoffJitter] of it. A pause never gets shorter.
  void failed(String providerId, [Duration? retryAfter]) {
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
    final current = state[providerId];
    if (current == null || until.isAfter(current)) {
      state = {...state, providerId: until};
    }
  }

  /// Lifts every pause (Retry, Search again, Clear saved lyrics).
  void clear() => state = const {};

  /// Whether the pause of [providerId] is still running.
  bool isPaused(String providerId) => pausedUntil(providerId) != null;

  /// When the pause of [providerId] ends, or `null` when it is not paused.
  DateTime? pausedUntil(String providerId) =>
      _running(state[providerId], ref.read(onlineLyricsClockProvider)());

  /// Whether any source is paused. Used by tests and diagnostics only; the
  /// lookups ask [isPaused] per source.
  bool get isBlocked {
    final now = ref.read(onlineLyricsClockProvider)();
    return state.values.any((until) => _running(until, now) != null);
  }
}

DateTime? _running(DateTime? until, DateTime now) =>
    until != null && now.isBefore(until) ? until : null;

final onlineLyricsBackoffProvider =
    NotifierProvider<OnlineLyricsBackoff, Map<String, DateTime>>(
      OnlineLyricsBackoff.new,
    );
