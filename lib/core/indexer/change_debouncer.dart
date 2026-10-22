import 'dart:async';

/// Makes a timer; tests pass a fake one to move time by hand.
typedef TimerFactory = Timer Function(Duration duration, void Function() cb);

/// How many quiet scans in a row may be repeated at the short delay because
/// a file keeps changing; after that the long delay applies.
const _maxQuickRetries = 5;

/// Turns noted changes into one call of [onFire] per burst: [quiet] after the
/// last change, or at latest [maxWait] after the first one of the burst. A
/// failed scan delays the next call by [backoff]; files left unread because
/// they were still being written get another call. Knows nothing of files:
/// the folder watcher tells it what happened.
class ChangeDebouncer {
  ChangeDebouncer({
    required this.onFire,
    required this.isActive,
    this.timer = Timer.new,
    this.quiet = const Duration(seconds: 3),
    this.maxWait = const Duration(seconds: 60),
    this.backoff = const Duration(seconds: 60),
  });

  final void Function() onFire;

  /// Whether calls may still happen (the watcher is alive and watching).
  final bool Function() isActive;
  final TimerFactory timer;

  /// Silence after the last change that starts a scan.
  final Duration quiet;

  /// Longest wait from the first change of a burst to the scan.
  final Duration maxWait;

  /// Pause after a failed scan before the next one.
  final Duration backoff;

  Timer? _quietTimer, _maxTimer, _backoffTimer;
  bool _waitingForBackoff = false;
  int _quickRetries = 0;

  /// A change happened.
  void note() => _schedule(quiet);

  /// A scan that [onFire] asked for ended. [deferred] counts the files it
  /// left unread because they were still being written.
  void scanEnded({required bool failed, required int deferred}) {
    if (!isActive()) return;
    if (failed) {
      _backoffTimer?.cancel();
      _backoffTimer = timer(backoff, () {
        _backoffTimer = null;
        if (_waitingForBackoff) {
          _waitingForBackoff = false;
          _fire();
        }
      });
    }
    if (deferred > 0) {
      _quickRetries++;
      // Files that never settle must slow the retries down, not loop.
      _schedule(_quickRetries <= _maxQuickRetries ? quiet : maxWait);
    } else {
      _quickRetries = 0;
    }
  }

  /// Drops what is pending; a backoff in progress keeps running.
  void cancel() {
    _cancelTimers();
    _waitingForBackoff = false;
  }

  void dispose() {
    _cancelTimers();
    _backoffTimer?.cancel();
    _backoffTimer = null;
  }

  void _schedule(Duration delay) {
    if (!isActive()) return;
    _quietTimer?.cancel();
    _quietTimer = timer(delay, _fire);
    _maxTimer ??= timer(maxWait, _fire);
  }

  void _cancelTimers() {
    _quietTimer?.cancel();
    _maxTimer?.cancel();
    _quietTimer = _maxTimer = null;
  }

  void _fire() {
    _cancelTimers();
    if (!isActive()) return;
    if (_backoffTimer != null) {
      _waitingForBackoff = true;
      return;
    }
    onFire();
  }
}
