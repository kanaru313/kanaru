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
class SongRowCache {
  SongRowCache({
    required this.load,
    required this.onChanged,
    this.maxRows = 1200,
    this.pageSize = songPageSize,
  });

  final SongRowLoader load;

  /// Called when rows arrive, so the list can draw them.
  final void Function() onChanged;
  final int maxRows;
  final int pageSize;

  var _generation = 0;
  var _disposed = false;
  List<int> _ids = const [];

  /// Insertion order is read order: the first key is the oldest.
  final _rows = <int, TrackListItem>{};

  /// Ids whose row was read under the current generation.
  final _fresh = <int>{};

  /// Pages being read under the current generation.
  final _loading = <int>{};

  /// Bumped by every [setIds]; a load ending under another value is dropped.
  int get generation => _generation;

  /// Rows held now.
  int get length => _rows.length;

  /// Replaces the id list and starts a new generation.
  void setIds(List<int> ids) {
    if (identical(ids, _ids)) return;
    _generation++;
    _ids = ids;
    _fresh.clear();
    _loading.clear();
  }

  /// Keeps [rows] as stale rows: shown until the real read replaces them.
  void seed(List<TrackListItem> rows) {
    for (final row in rows) {
      _rows[row.id] = row;
    }
  }

  /// The row at [index] of the id list, or null while it is not read. A
  /// stale row is returned and read again in the background.
  TrackListItem? rowAt(int index) {
    final id = _ids[index];
    if (!_fresh.contains(id)) _load(index ~/ pageSize);
    return _rows[id];
  }

  /// Drops everything, and every load still running.
  void dispose() {
    _disposed = true;
    _generation++;
    _rows.clear();
    _fresh.clear();
    _loading.clear();
  }

  void _load(int page) {
    if (_disposed || !_loading.add(page)) return;
    final generation = _generation;
    final start = page * pageSize;
    final end = start + pageSize < _ids.length ? start + pageSize : _ids.length;
    unawaited(
      load(_ids.sublist(start, end)).then(
        (rows) {
          if (generation != _generation) return;
          _loading.remove(page);
          for (final row in rows) {
            _rows.remove(row.id);
            _rows[row.id] = row;
            _fresh.add(row.id);
          }
          while (_rows.length > maxRows) {
            _fresh.remove(_rows.remove(_rows.keys.first)!.id);
          }
          onChanged();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (generation != _generation) return;
          // Asked for again when the list next draws this page.
          _loading.remove(page);
          _log.severe('Reading song rows failed', error, stackTrace);
        },
      ),
    );
  }
}
