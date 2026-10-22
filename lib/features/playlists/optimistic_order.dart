import 'package:flutter/foundation.dart';

/// Order shown while reorders are on their way to the database, so a
/// dropped row stays where it landed instead of jumping back until the
/// stream catches up.
class OptimisticOrder {
  List<int>? _pending;
  int _inFlight = 0;

  /// [rows] in the pending order. Ids gone from [rows] are dropped; ids new
  /// in [rows] (a concurrent add) keep their place after the known ones.
  List<T> apply<T>(List<T> rows, int Function(T row) idOf) {
    final pending = _pending;
    if (pending == null) return rows;
    // A map keeps the insertion order of [rows] for the leftovers.
    final byId = {for (final row in rows) idOf(row): row};
    return [for (final id in pending) ?byId.remove(id), ...byId.values];
  }

  /// A row was dropped: [ids] is the order it produced, and a write for it
  /// is under way.
  void begin(List<int> ids) {
    _pending = ids;
    _inFlight++;
  }

  /// The write of one [begin] finished. A failed one rolls the view back to
  /// the stream's order.
  void end({required bool ok}) {
    if (_inFlight > 0) _inFlight--;
    if (!ok) _pending = null;
  }

  /// A new value arrived from the stream, with its row [ids]. It replaces
  /// the pending order once no write is in flight or it already agrees with
  /// it; a stale value that arrives mid-write is ignored.
  ///
  /// Call this for new data only, not for every rebuild: a rebuild that
  /// repeats the previous value after [end] would drop the pending order
  /// and paint the old one for a frame.
  void onData(List<int> ids) {
    if (_inFlight == 0 || listEquals(ids, _pending)) _pending = null;
  }
}
