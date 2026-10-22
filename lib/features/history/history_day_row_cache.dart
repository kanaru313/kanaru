import 'dart:async';

import '../../core/database/history_rows.dart';
import 'history_error_log.dart';

/// Reads the plays of the local day starting at [dayStart] (epoch ms).
typedef HistoryDayLoader = Future<List<HistoryPlayRow>> Function(int dayStart);

/// The plays of the days the timeline has drawn, by day start.
///
/// The list only knows how many plays each day has; a day is read when a line
/// of it is first asked for. [invalidate] (the plays or the library changed)
/// starts a new generation: days already read stay drawn but count as stale
/// and are read again when asked for, and a read that began under an older
/// generation is dropped when it ends. At most [maxDays] days are kept, the
/// least recently asked go first.
///
/// Reads share one database connection, so at most [maxReads] run at once and
/// the others wait, newest request first: a fast scroll asks for many days it
/// has already left. A waiting day nobody asked for within [wantedFor] is
/// skipped; the list asks again for days still on screen each time it draws.
class HistoryDayRowCache {
  HistoryDayRowCache({
    required this.load,
    required this.onChanged,
    this.maxDays = 40,
    this.maxReads = 2,
    this.wantedFor = const Duration(milliseconds: 300),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final HistoryDayLoader load;

  /// Called when rows arrive, so the list can draw them.
  final void Function() onChanged;
  final int maxDays;
  final int maxReads;
  final Duration wantedFor;
  final DateTime Function() _now;

  var _generation = 0;
  var _disposed = false;

  /// Least recently asked first.
  final _rows = <int, List<HistoryPlayRow>>{};

  /// Days answered under the current generation.
  final _fresh = <int>{};

  /// Days waiting or being read under the current generation.
  final _loading = <int>{};

  /// Days waiting for a free read, the newest request last.
  final _queue = <int>[];
  final _askedAt = <int, DateTime>{};

  /// Reads started and not ended, of any generation.
  var _reading = 0;

  /// Reads started and not ended.
  int get reading => _reading;

  /// Days held now.
  int get length => _rows.length;

  /// The plays of the day starting at [dayStart], or null while it was never
  /// read. A stale day is returned and read again in the background.
  List<HistoryPlayRow>? rowsOf(int dayStart) {
    final rows = _rows.remove(dayStart);
    if (rows != null) _rows[dayStart] = rows;
    if (!_fresh.contains(dayStart)) _ask(dayStart);
    return rows;
  }

  /// Marks every day stale; what is held stays drawn until read again.
  void invalidate() {
    _generation++;
    _fresh.clear();
    _loading.clear();
    _queue.clear();
    _askedAt.clear();
  }

  /// Drops everything, and every read still running.
  void dispose() {
    _disposed = true;
    invalidate();
    _rows.clear();
  }

  void _ask(int day) {
    if (_disposed) return;
    _askedAt[day] = _now();
    if (!_loading.add(day)) {
      // Waiting: it is the newest request now.
      if (_queue.remove(day)) _queue.add(day);
      return;
    }
    _queue.add(day);
    _startReads();
  }

  void _startReads() {
    while (_reading < maxReads && _queue.isNotEmpty) {
      final day = _queue.removeLast();
      if (_now().difference(_askedAt[day]!) > wantedFor) {
        _loading.remove(day);
        _askedAt.remove(day);
        continue;
      }
      _read(day);
    }
  }

  void _read(int day) {
    final generation = _generation;
    _reading++;
    unawaited(
      load(day).then(
        (rows) {
          _reading--;
          if (generation == _generation && !_disposed) {
            _loading.remove(day);
            _askedAt.remove(day);
            _fresh.add(day);
            _rows.remove(day);
            _rows[day] = rows;
            while (_rows.length > maxDays) {
              _fresh.remove(_rows.keys.first);
              _rows.remove(_rows.keys.first);
            }
            onChanged();
          }
          _startReads();
        },
        onError: (Object error, StackTrace stackTrace) {
          _reading--;
          if (generation == _generation) {
            // Asked for again when the list next draws this day.
            _loading.remove(day);
            _askedAt.remove(day);
            logHistoryError('Reading the plays of a day failed', error);
          }
          _startReads();
        },
      ),
    );
  }
}
