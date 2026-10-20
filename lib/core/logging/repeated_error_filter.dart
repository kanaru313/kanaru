import 'dart:async';

/// Folds an uncaught error that repeats (a widget that throws on every
/// frame) into one record and a count, so it cannot fill the log file or
/// starve the UI isolate with writes.
///
/// Errors are told apart by a key ([keyFor]). The first one inside a window is
/// written; later ones in the same window only add to a count. A few recent
/// keys are tracked at once, so two errors that alternate each frame (a build
/// error and a layout assertion) are both folded. The count of a key is
/// reported through [onSummary] when its window ends, when it is evicted to
/// make room for a newer key, or at [close]. A key that arrives after its
/// window is written again; distinct errors are never dropped.
///
/// Pure Dart with an injectable clock and timer, so tests need no real time.
class RepeatedErrorFilter {
  RepeatedErrorFilter({
    required this.onSummary,
    this.window = const Duration(seconds: 10),
    this.maxKeys = 8,
    DateTime Function()? now,
    Timer Function(Duration delay, void Function() callback)? startTimer,
  }) : _now = now ?? DateTime.now,
       _startTimer = startTimer ?? Timer.new;

  /// Receives the text of a "repeated ×N" record. Called synchronously from
  /// [shouldWrite] or from a window timer; never from [close], which returns
  /// the text instead.
  final void Function(String summary) onSummary;

  /// How long after the first occurrence the same error stays folded.
  final Duration window;

  /// How many different errors are tracked at once. The oldest is reported
  /// and dropped when another arrives.
  final int maxKeys;

  final DateTime Function() _now;
  final Timer Function(Duration, void Function()) _startTimer;

  /// Oldest first; a key that is written again moves to the end.
  final _entries = <String, _Entry>{};

  static const _maxFrameChars = 200;
  static const _maxTextChars = 200;
  static final _spaces = RegExp(r'\s+');

  /// Key of an error: its runtime type, the first stack frame that is not in
  /// the Dart SDK or the Flutter framework (those frames are shared by
  /// unrelated bugs), and the start of its text. Without such a frame the key
  /// holds a hash of the first five frames; without a stack, the text alone
  /// tells errors apart. Not redacted here; the summary goes through the log
  /// session's write, which redacts and escapes it.
  static String keyFor(Object error, StackTrace? stack) {
    final frame = stack == null ? '' : _callSite(stack.toString());
    var text = '$error'.trim().replaceAll(_spaces, ' ');
    if (text.length > _maxTextChars) {
      text = '${text.substring(0, _maxTextChars)}…';
    }
    return '${error.runtimeType}${frame.isEmpty ? '' : ' $frame'} | $text';
  }

  static String _callSite(String stack) {
    final frames = stack
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('<'))
        .toList();
    for (final frame in frames) {
      if (frame.contains('(dart:') || frame.contains('(package:flutter/')) {
        continue;
      }
      return frame.length > _maxFrameChars
          ? '${frame.substring(0, _maxFrameChars)}…'
          : frame;
    }
    if (frames.isEmpty) return '';
    return '#${Object.hashAll(frames.take(5)).toRadixString(16)}';
  }

  /// Whether the error with this [key] should be written. `false` means it
  /// is a repeat inside the window and was only counted.
  ///
  /// When it returns `true`, the summary of what was folded under an evicted
  /// or expired entry has already been passed to [onSummary], so it precedes
  /// the new record.
  bool shouldWrite(String key) {
    final now = _now();
    final entry = _entries[key];
    if (entry != null) {
      if (now.difference(entry.start) < window) {
        entry.pending++;
        return false;
      }
      _report(_drop(key));
    }
    while (_entries.length >= maxKeys) {
      _report(_drop(_entries.keys.first));
    }
    final fresh = _Entry(now);
    fresh.timer = _startTimer(window, () => _windowEnded(key, fresh));
    _entries[key] = fresh;
    return true;
  }

  /// Stops the timers and returns the summaries of folded repeats not
  /// reported yet, oldest error first.
  List<String> close() => [
    for (final key in _entries.keys.toList()) ?_drop(key),
  ];

  void _report(String? summary) {
    if (summary != null) onSummary(summary);
  }

  void _windowEnded(String key, _Entry entry) {
    if (!identical(_entries[key], entry)) return;
    entry.timer = null;
    _report(_drop(key));
  }

  /// Forgets [key] and returns what was folded under it, or `null`.
  String? _drop(String key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    entry.timer?.cancel();
    entry.timer = null;
    if (entry.pending == 0) return null;
    return 'Uncaught error repeated ×${entry.pending}: $key';
  }
}

class _Entry {
  _Entry(this.start);
  final DateTime start;
  int pending = 0;
  Timer? timer;
}
