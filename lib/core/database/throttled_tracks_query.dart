import 'dart:async';

import 'package:drift/drift.dart';

import 'library_database.dart';

/// Runs [load] when listened to and again after `tracks` changes, but never
/// two loads at once and never sooner than [interval] after the previous
/// load finished.
///
/// For whole-library lists (albums, artists, songs): drift's `.watch()` cancels
/// and restarts such a query after every write, so during a scan it keeps the
/// database isolate busy, slows the scan several times over and never emits.
/// Here a write only marks the result dirty; a running load is never
/// cancelled, so a result always arrives, at most [interval] late.
///
/// A failed load is emitted as an error and later changes still load. While
/// paused nothing loads; resuming after a change loads once. Cancelling stops
/// the timer and drops a result that arrives afterwards.
Stream<T> throttledTracksQuery<T>(
  LibraryDatabase db,
  Future<T> Function() load, {
  required Duration interval,
}) => _ThrottledQuery(db, load, interval).controller.stream;

class _ThrottledQuery<T> {
  _ThrottledQuery(this._db, this._load, this._interval) {
    controller = StreamController<T>(
      onListen: _onListen,
      onPause: () => _paused = true,
      onResume: () {
        _paused = false;
        _schedule();
      },
      onCancel: _onCancel,
    );
  }

  final LibraryDatabase _db;
  final Future<T> Function() _load;
  final Duration _interval;
  late final StreamController<T> controller;

  StreamSubscription<void>? _updates;

  /// Runs from the end of a load until the next one may start.
  Timer? _cooldown;
  bool _loading = false;

  /// `tracks` changed since the last load started (true before the first).
  bool _dirty = true;
  bool _paused = false;
  bool _cancelled = false;

  void _onListen() {
    _updates = _db.tableUpdates(TableUpdateQuery.onTable(_db.tracks)).listen((
      _,
    ) {
      _dirty = true;
      _schedule();
    });
    _schedule();
  }

  Future<void> _onCancel() async {
    _cancelled = true;
    _cooldown?.cancel();
    await _updates?.cancel();
  }

  void _schedule() {
    if (_cancelled || _paused || _loading || !_dirty) return;
    if (_cooldown != null) return;
    unawaited(_run());
  }

  Future<void> _run() async {
    _loading = true;
    _dirty = false;
    try {
      final result = await _load();
      if (!_cancelled) controller.add(result);
    } catch (error, stackTrace) {
      if (!_cancelled) controller.addError(error, stackTrace);
    } finally {
      _loading = false;
    }
    if (_cancelled) return;
    if (_interval > Duration.zero) {
      _cooldown = Timer(_interval, () {
        _cooldown = null;
        _schedule();
      });
    }
    _schedule();
  }
}
