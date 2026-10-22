import 'dart:async';

import 'package:logging/logging.dart';

import 'album_run_lookup.dart';
import 'replay_gain_options.dart';

final _log = Logger('player');

/// Album keys of tracks by path, read through [AlbumRunKeyLookup] and kept
/// for the session.
///
/// A path the lookup did not return is cached as having no album. Nothing is
/// invalidated: a file retagged after it was read keeps its old key until it
/// is evicted or the app restarts, and a track that is only keyed after its
/// neighbours were (a fresh scan) stays "no album" the same way. Both are
/// accepted: a wrong level lasts one session at most.
class AlbumRunKeyCache {
  AlbumRunKeyCache(this._lookup);

  /// Most paths kept; the oldest go first.
  static const _cacheSize = 256;

  final AlbumRunKeyLookup _lookup;
  bool _disposed = false;

  /// Key of each path read so far, `null` for a path that has none.
  final _keys = <String, AlbumRunKey?>{};

  /// Lookups in flight, by path, so a path is never asked for twice at once.
  final _fetching = <String, Future<void>>{};
  String? _lastLookupError;

  /// Whether [path] was read (with or without an album).
  bool has(String path) => _keys.containsKey(path);

  /// The key of [path], `null` when it has none or was not read yet.
  AlbumRunKey? operator [](String path) => _keys[path];

  /// Completes once every path in [paths] is cached or its lookup failed.
  /// Paths already being read are waited for, not asked for again.
  Future<void> ensure(Iterable<String> paths) {
    if (_disposed) return Future.value();
    final waits = <Future<void>>[];
    final fresh = <String>[];
    for (final path in paths) {
      if (_keys.containsKey(path)) continue;
      final inFlight = _fetching[path];
      if (inFlight != null) {
        waits.add(inFlight);
      } else {
        fresh.add(path);
      }
    }
    if (fresh.isNotEmpty) {
      final run = _fill(fresh)
          .whenComplete(() => fresh.forEach(_fetching.remove));
      for (final path in fresh) {
        _fetching[path] = run;
      }
      waits.add(run);
    }
    return Future.wait(waits);
  }

  /// Stops filling the cache from lookups that are still running.
  void dispose() => _disposed = true;

  /// Reads the keys of [paths] into the cache. A failure is logged once per
  /// message and caches nothing, so the paths are asked again later;
  /// meanwhile they count as no album.
  Future<void> _fill(List<String> paths) async {
    try {
      final found = await _lookup(paths);
      if (_disposed) return;
      for (final path in paths) {
        _keys.remove(path);
        _keys[path] = found[path];
      }
      while (_keys.length > _cacheSize) {
        _keys.remove(_keys.keys.first);
      }
      _lastLookupError = null;
    } on Object catch (error, stack) {
      final message = '$error';
      if (message != _lastLookupError) {
        _log.warning('Looking up album keys failed', error, stack);
      }
      _lastLookupError = message;
    }
  }
}
