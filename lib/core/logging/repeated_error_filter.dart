import 'dart:async';

/// Folds an uncaught error that repeats (a widget that throws on every
/// frame) into one record and a count, so it cannot fill the log file or
/// starve the UI isolate with writes.
///
/// Errors are told apart by a label ([labelFor]): same type and same first
/// stack frame is the same error. The first one inside a window is written;
/// later ones in the same window only add to a count. The count is reported
/// through [onSummary] when a different error arrives, when the window ends,
/// or at [close]. There is no other limit: distinct errors are never dropped.
///
/// Pure Dart with an injectable clock and timer, so tests need no real time.
class RepeatedErrorFilter {
  RepeatedErrorFilter({
    required this.onSummary,
    this.window = const Duration(seconds: 10),
    DateTime Function()? now,
    Timer Function(Duration delay, void Function() callback)? startTimer,
  }) : _now = now ?? DateTime.now,
       _startTimer = startTimer ?? Timer.new;

  /// Receives the text of a "repeated ×N" record. Called synchronously from
  /// [shouldWrite] or from the window timer; never from [close], which
  /// returns the text instead.
  final void Function(String summary) onSummary;

  /// How long after the first occurrence the same error stays folded.
  final Duration window;

  final DateTime Function() _now;
  final Timer Function(Duration, void Function()) _startTimer;

  String? _label;
  DateTime _windowStart = DateTime.fromMillisecondsSinceEpoch(0);
  int _pending = 0;
  Timer? _timer;

  /// Label of an error: its runtime type and the first line of its stack
  /// trace (capped). Not redacted here; the summary goes through the log
  /// session's write, which redacts and escapes it.
  static String labelFor(Object error, StackTrace? stack) {
    var frame = '';
    if (stack != null) {
      final text = stack.toString().trimLeft();
      final end = text.indexOf('\n');
      frame = (end < 0 ? text : text.substring(0, end)).trimRight();
      if (frame.length > 200) frame = '${frame.substring(0, 200)}…';
    }
    return frame.isEmpty
        ? '${error.runtimeType}'
        : '${error.runtimeType} $frame';
  }

  /// Whether the error with this [label] should be written. `false` means it
  /// is a repeat inside the window and was only counted.
  ///
  /// When it returns `true` after folded repeats, the summary of those has
  /// already been passed to [onSummary], so it precedes the new record.
  bool shouldWrite(String label) {
    final now = _now();
    if (label == _label && now.difference(_windowStart) < window) {
      _pending++;
      return false;
    }
    _flush();
    _label = label;
    _windowStart = now;
    _timer = _startTimer(window, _windowEnded);
    return true;
  }

  /// Stops the timer and returns the summary of folded repeats not reported
  /// yet, or `null`.
  String? close() {
    _timer?.cancel();
    _timer = null;
    final summary = _takeSummary();
    _label = null;
    return summary;
  }

  void _windowEnded() {
    _timer = null;
    _flush();
    _label = null;
  }

  void _flush() {
    _timer?.cancel();
    _timer = null;
    final summary = _takeSummary();
    if (summary != null) onSummary(summary);
  }

  String? _takeSummary() {
    if (_pending == 0) return null;
    final text = 'Uncaught error repeated ×$_pending: $_label';
    _pending = 0;
    return text;
  }
}
