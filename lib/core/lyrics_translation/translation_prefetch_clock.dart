import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Real playing time of a playthrough before the queue is translated ahead,
/// so skipping through songs sends nothing. Tests shorten it.
final translationPrefetchDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

/// Where the prefetch clock reads time and gets timers from; tests replace it
/// with one they advance by hand.
class PrefetchTimeSource {
  PrefetchTimeSource() {
    _watch.start();
  }

  final _watch = Stopwatch();

  Duration now() => _watch.elapsed;

  Timer timer(Duration after, void Function() onFire) => Timer(after, onFire);
}

final translationPrefetchTimeProvider = Provider<PrefetchTimeSource>(
  (ref) => PrefetchTimeSource(),
);

/// Measures how long the current playthrough has played, in wall-clock time
/// (never the position, so a seek or a restored session counts nothing).
/// Pausing keeps the time played; a new playthrough starts again. The result
/// belongs to the playthrough it measured: [isReady] is true only for that
/// value, so a stale answer can never serve the next song.
class PrefetchClock {
  PrefetchClock(this._source, this._delay, this._onReady);

  final PrefetchTimeSource _source;
  final Duration _delay;
  final void Function() _onReady;

  int? _measuring;
  int? _readyFor;
  var _played = Duration.zero;
  Duration? _since;
  Timer? _timer;

  bool isReady(int playthrough) => _readyFor == playthrough;

  /// Brings the clock in line with the player. The timer that ends the wait is
  /// armed only when [wanted] (there is something to translate ahead).
  void sync({
    required int playthrough,
    required bool playing,
    required bool wanted,
  }) {
    if (playthrough != _measuring) {
      _measuring = playthrough;
      _played = Duration.zero;
      _since = null;
      _readyFor = null;
    }
    _timer?.cancel();
    _timer = null;
    final now = _source.now();
    if (!playing) {
      final since = _since;
      if (since != null) _played += now - since;
      _since = null;
      return;
    }
    final since = _since ??= now;
    if (_readyFor == playthrough || !wanted) return;
    final left = _delay - (_played + (now - since));
    _timer = _source.timer(left.isNegative ? Duration.zero : left, () {
      _readyFor = playthrough;
      _onReady();
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
