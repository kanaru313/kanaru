import 'dart:async';

import 'package:logging/logging.dart';

import '../../../core/database/library_database.dart' show TrackListItem;
import '../../../core/database/library_song_paging.dart';

final _log = Logger('library');

/// Reads the rows of the given ids, in that order.
typedef SongRowLoader = Future<List<TrackListItem>> Function(List<int> ids);

/// The rows of the Songs list read so far, by track id.
///
/// The list only knows the ids in order. A row is read, a page of
/// [pageSize] ids at a time, when the list first asks for it. A new id list
/// starts a new generation: rows already read stay on screen but count as
/// stale and are read again when asked for, and a page load that started
/// under an older generation is dropped when it ends, so an old answer
/// never replaces a newer one. At most [maxRows] rows are kept, the oldest
/// read go first.
///
/// Reads share one database connection, so at most [maxReads] run at once
/// and the others wait, newest request first: scrolling fast asks for many
/// pages the list has already left. A waiting page nobody asked for within
/// [wantedFor] is skipped; the list asks again for pages still on screen
/// each time it redraws.
class SongRowCache {
  SongRowCache({
    required this.load,
    required this.onChanged,
    this.maxRows = 1200,
    this.pageSize = songPageSize,
    this.maxReads = 2,
    this.wantedFor = const Duration(milliseconds: 300),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SongRowLoader load;

  /// Called when rows arrive, so the list can draw them.
  final void Function() onChanged;
  final int maxRows;
  final int pageSize;
  final int maxReads;
  final Duration wantedFor;
  final DateTime Function() _now;

  var _generation = 0;
  var _disposed = false;
  List<int> _ids = const [];

  /// Insertion order is read order: the first key is the oldest.
  final _rows = <int, TrackListItem>{};

  /// Ids asked for under the current generation and answered, with or
  /// without a row: an id the database no longer has is not asked for again
  /// until the next id list.
  final _fresh = <int>{};

  /// Pages waiting or being read under the current generation.
  final _loading = <int>{};

  /// Pages waiting for a free read, the newest request last.
  final _queue = <int>[];

  /// When each page in [_loading] was last asked for.
  final _askedAt = <int, DateTime>{};

  /// Reads started and not ended, of any generation.
  var _reading = 0;

  /// Bumped by every [setIds]; a load ending under another value is dropped.
  int get generation => _generation;

  /// Rows held now.
  int get length => _rows.length;

  /// Reads started and not ended.
  int get reading => _reading;

  /// Replaces the id list and starts a new generation.
  ///
  /// Every refresh reads the pages on screen again, even when their ids are
  /// the same, so edited tags show up; the rows already read stay drawn
  /// until the new ones arrive.
  void setIds(List<int> ids) {
    if (identical(ids, _ids)) return;
    _generation++;
    _ids = ids;
    _fresh.clear();
    _loading.clear();
    _queue.clear();
    _askedAt.clear();
  }

  /// Keeps [rows] as stale rows: shown until the real read replaces them.
  void seed(List<TrackListItem> rows) {
    for (final row in rows) {
      _rows[row.id] = row;
    }
  }

  /// The row at [index] of the id list, or null while it is not read or the
  /// track is gone. A stale row is returned and read again in the background.
  TrackListItem? rowAt(int index) {
    final id = _ids[index];
    if (!_fresh.contains(id)) _ask(index ~/ pageSize);
    return _rows[id];
  }

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

  void _ask(int page) {
    if (_disposed) return;
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
    while (_reading < maxReads && _queue.isNotEmpty) {
      final page = _queue.removeLast();
      if (_now().difference(_askedAt[page]!) > wantedFor) {
        _loading.remove(page);
        _askedAt.remove(page);
        continue;
      }
      _read(page);
    }
  }

  void _read(int page) {
    final generation = _generation;
    final start = page * pageSize;
    final end = start + pageSize < _ids.length ? start + pageSize : _ids.length;
    final ids = _ids.sublist(start, end);
    _reading++;
    unawaited(
      load(ids).then(
        (rows) {
          _reading--;
          if (generation == _generation) {
            _loading.remove(page);
            _askedAt.remove(page);
            _ended(ids, rows);
          }
          _startReads();
        },
        onError: (Object error, StackTrace stackTrace) {
          _reading--;
          if (generation == _generation) {
            // Asked for again when the list next draws this page.
            _loading.remove(page);
            _askedAt.remove(page);
            _log.severe('Reading song rows failed', error, stackTrace);
          }
          _startReads();
        },
      ),
    );
  }

  /// Stores the answer for [ids]; ids without a row are gone from the
  /// library and count as answered.
  void _ended(List<int> ids, List<TrackListItem> rows) {
    for (final id in ids) {
      _fresh.add(id);
    }
    for (final row in rows) {
      _rows.remove(row.id);
      _rows[row.id] = row;
    }
    final answered = {for (final row in rows) row.id};
    for (final id in ids) {
      if (!answered.contains(id)) _rows.remove(id);
    }
    while (_rows.length > maxRows) {
      _fresh.remove(_rows.remove(_rows.keys.first)!.id);
    }
    onChanged();
  }
}
