import 'dart:async';
import 'dart:math' as math;

import 'package:logging/logging.dart';

import '../../core/database/playlist_rows.dart';

final _log = Logger('playlists');

/// Reads the entries stored at positions `start` up to `start + count`.
typedef PlaylistPageLoader = Future<List<PlaylistPositionedEntry>> Function(
  int start,
  int count,
);

/// The entries of one playlist read so far, by index in the list.
///
/// The page view only knows how many entries there are. A row is read, a
/// page of [pageSize] by position range at a time, when the list first asks
/// for it. Rows are placed by the position the database returns, not by the
/// order of the answer, so a gap or a duplicate position left by an outside
/// tool gives a placeholder, never a crash or a shifted list.
///
/// [reset] starts a new generation: rows already read stay on screen but
/// count as stale and are read again when asked for, and a page read that
/// started under an older generation is dropped when it ends, so an old
/// answer never replaces a newer one. At most [maxRows] rows are kept, the
/// oldest read go first.
///
/// [move] and [removeAt] edit the cached rows the way the database edit will,
/// so an edit shows at once without reading the playlist again. While a
/// write runs the view [hold]s the cache: no read starts and the answers of
/// reads already running are dropped, because they would show a state the
/// write is about to change.
///
/// Reads share one database connection, so at most [maxReads] run at once
/// and the others wait, newest request first: scrolling fast asks for many
/// pages the list has already left. A waiting page nobody asked for within
/// [wantedFor] is skipped; the list asks again for pages still on screen
/// each time it redraws.
class PlaylistRowCache {
  PlaylistRowCache({
    required this.load,
    required this.onChanged,
    this.pageSize = 100,
    this.maxRows = 1200,
    this.maxReads = 2,
    this.wantedFor = const Duration(milliseconds: 300),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PlaylistPageLoader load;

  /// Called when rows arrive or a page that was asked for will not arrive
  /// (so the list asks again for the pages still on screen). Never called
  /// while the list is building.
  final void Function() onChanged;
  final int pageSize;
  final int maxRows;
  final int maxReads;
  final Duration wantedFor;
  final DateTime Function() _now;

  var _generation = 0;
  var _disposed = false;
  var _held = false;
  var _count = 0;
  var _notifyScheduled = false;

  /// Index to row. Insertion order is read order: the first key is the
  /// oldest.
  final _rows = <int, PlaylistEntryRow>{};

  /// Pages answered under the current generation and not edited since.
  final _fresh = <int>{};

  /// Pages waiting or being read under the current generation.
  final _loading = <int>{};

  /// Pages waiting for a free read, the newest request last.
  final _queue = <int>[];

  /// When each page in [_loading] was last asked for.
  final _askedAt = <int, DateTime>{};

  /// Reads started and not ended, of any generation.
  var _reading = 0;

  /// Number of entries in the list.
  int get count => _count;

  /// Bumped by every [reset], [hold], [move] and [removeAt]; a read ending
  /// under another value is dropped.
  int get generation => _generation;

  /// Rows held now.
  int get length => _rows.length;

  /// Reads started and not ended.
  int get reading => _reading;

  /// Whether the cache is held (see [hold]).
  bool get held => _held;

  /// Sets the list length to [count] and starts a new generation.
  ///
  /// Every reset reads the pages on screen again, even when nothing changed,
  /// so edits made elsewhere show up; the rows already read stay drawn until
  /// the new ones arrive.
  void reset(int count) {
    _newGeneration();
    _count = count;
    _fresh.clear();
    _rows.removeWhere((index, _) => index >= count);
  }

  /// The row at [index], or null while it is not read, is a gap, or [index]
  /// is outside the list. A stale row is returned and read again in the
  /// background.
  PlaylistEntryRow? rowAt(int index) {
    if (index < 0 || index >= _count) return null;
    final page = index ~/ pageSize;
    if (!_fresh.contains(page)) _ask(page);
    return _rows[index];
  }

  /// The index of the cached row of entry [entryId], or null when it is not
  /// cached. Costs the number of cached rows.
  int? indexOfEntry(int entryId) {
    for (final MapEntry(:key, :value) in _rows.entries) {
      if (value.entryId == entryId) return key;
    }
    return null;
  }

  /// Moves the cached row at [from] to [to], shifting the rows between, as
  /// `list.insert(to, list.removeAt(from))` does. A row not cached stays not
  /// cached. Costs the number of cached rows, not the list length.
  void move(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= _count || to >= _count) {
      return;
    }
    _newGeneration();
    final moved = {
      for (final MapEntry(:key, :value) in _rows.entries)
        _movedIndex(key, from, to): value,
    };
    _rows
      ..clear()
      ..addAll(moved);
    _fresh.removeWhere(
      (page) =>
          page >= math.min(from, to) ~/ pageSize &&
          page <= math.max(from, to) ~/ pageSize,
    );
  }

  /// Removes the row at [index]: the list gets one shorter and the cached
  /// rows after it move up.
  void removeAt(int index) {
    if (index < 0 || index >= _count) return;
    _newGeneration();
    final shifted = {
      for (final MapEntry(:key, :value) in _rows.entries)
        if (key != index) (key > index ? key - 1 : key): value,
    };
    _rows
      ..clear()
      ..addAll(shifted);
    _count--;
    _fresh.removeWhere((page) => page >= index ~/ pageSize);
  }

  /// A write is under way: no page read starts, and the answer of every
  /// read running now is dropped. Pending requests are forgotten; the list
  /// asks again after [release].
  void hold() {
    _held = true;
    _newGeneration();
  }

  /// The writes are done: reads start again for the pages the list asks for.
  /// The owner calls [reset] with the stored count and redraws.
  void release() => _held = false;

  /// Drops everything, and every load still running.
  void dispose() {
    _disposed = true;
    _generation++;
    _rows.clear();
    _fresh.clear();
    _loading.clear();
    _queue.clear();
    _askedAt.clear();
  }

  static int _movedIndex(int index, int from, int to) {
    if (index == from) return to;
    if (from < to && index > from && index <= to) return index - 1;
    if (from > to && index >= to && index < from) return index + 1;
    return index;
  }

  /// Forgets what was asked: the answers on their way belong to the state
  /// before the change.
  void _newGeneration() {
    _generation++;
    _loading.clear();
    _queue.clear();
    _askedAt.clear();
  }

  void _ask(int page) {
    if (_disposed || _held) return;
    _askedAt[page] = _now();
    if (!_loading.add(page)) {
      // Waiting: it is the newest request now.
      if (_queue.remove(page)) _queue.add(page);
      return;
    }
    _queue.add(page);
    _startReads();
  }

  void _startReads() {
    if (_held) return;
    while (_reading < maxReads && _queue.isNotEmpty) {
      final page = _queue.removeLast();
      if (_now().difference(_askedAt[page]!) > wantedFor) {
        _loading.remove(page);
        _askedAt.remove(page);
        // The page may be on screen again by now: let the list ask again.
        _notifyLater();
        continue;
      }
      _read(page);
    }
  }

  void _read(int page) {
    final generation = _generation;
    final start = page * pageSize;
    final count = math.min(pageSize, _count - start);
    if (count <= 0) {
      _loading.remove(page);
      _askedAt.remove(page);
      return;
    }
    _reading++;
    unawaited(
      load(start, count).then(
        (rows) {
          _reading--;
          if (_disposed) return;
          if (generation == _generation) {
            _loading.remove(page);
            _askedAt.remove(page);
            _ended(page, start, count, rows);
          } else {
            // Dropped, but the page may still be on screen: ask again.
            onChanged();
          }
          _startReads();
        },
        onError: (Object error, StackTrace stackTrace) {
          _reading--;
          if (_disposed) return;
          if (generation == _generation) {
            // Asked for again when the list next draws this page.
            _loading.remove(page);
            _askedAt.remove(page);
            _log.severe('Reading playlist rows failed', error, stackTrace);
          } else {
            onChanged();
          }
          _startReads();
        },
      ),
    );
  }

  /// Stores the answer for the page at [start]. Rows go to the index of
  /// their position; those outside the page or the list are dropped, and an
  /// index in the page that got no row is a gap and loses its stale row.
  void _ended(
    int page,
    int start,
    int count,
    List<PlaylistPositionedEntry> rows,
  ) {
    final answered = <int>{};
    for (final row in rows) {
      final index = row.position;
      if (index < start || index >= start + count || index >= _count) continue;
      _rows.remove(index);
      _rows[index] = row.entry;
      answered.add(index);
    }
    for (var index = start; index < start + count; index++) {
      if (!answered.contains(index)) _rows.remove(index);
    }
    _fresh.add(page);
    while (_rows.length > maxRows) {
      final oldest = _rows.keys.first;
      _rows.remove(oldest);
      _fresh.remove(oldest ~/ pageSize);
    }
    onChanged();
  }

  /// [onChanged] after the current synchronous work, once: the list may be
  /// in the middle of building, where it cannot be marked dirty.
  void _notifyLater() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_disposed) onChanged();
    });
  }
}
