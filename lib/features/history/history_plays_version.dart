import 'dart:async';

import 'package:drift/drift.dart'
    show TableUpdate, TableUpdateQuery, UpdateKind;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_startup.dart';

/// How long changes to `plays` are collected before the page reads again.
const historyPlaysDebounce = Duration(milliseconds: 250);

/// Whether a batch of `plays` updates changes what the page shows. The
/// recorder checkpoints `listened_ms` with plain updates about every 30
/// seconds, which no row shows; any other kind counts, and so does an update
/// with no kind (a custom statement), as nothing says what it did.
bool historyBatchChangesRows(Set<TableUpdate> batch) =>
    batch.any((u) => u.kind != UpdateKind.update);

/// A number that goes up when the plays on show may have changed: the one
/// signal every provider and cache of the page reads again on.
///
/// One subscription to the `plays` table serves the whole page. Batches of
/// updates only are ignored; the others are collected for
/// [historyPlaysDebounce] and then bump the number once.
final historyPlaysVersionProvider =
    NotifierProvider.autoDispose<HistoryPlaysVersion, int>(
      HistoryPlaysVersion.new,
    );

class HistoryPlaysVersion extends Notifier<int> {
  Timer? _timer;
  var _onlyInserts = true;

  /// Set once a bump brought a change other than new plays and kept until
  /// [applied].
  var _mustApplyNow = false;

  /// The latest bump deleted or changed rows (or something unknown), not only
  /// added plays. A page scrolled away from the top may hold back additions,
  /// never this.
  bool get mustApplyNow => _mustApplyNow;

  /// The page has shown what was read after the latest bump.
  void applied() => _mustApplyNow = false;

  /// The next bump must not be held back, whatever it holds: the page itself
  /// puts a play back (Undo) and wants to see it.
  void applyNextNow() => _onlyInserts = false;

  @override
  int build() {
    final db = ref.watch(libraryDatabaseProvider);
    ref.onDispose(() => _timer?.cancel());
    if (db != null) {
      final updates = db
          .tableUpdates(TableUpdateQuery.onTable(db.plays))
          .listen(_onBatch);
      ref.onDispose(updates.cancel);
    }
    return 0;
  }

  void _onBatch(Set<TableUpdate> batch) {
    if (!historyBatchChangesRows(batch)) return;
    // A checkpoint update next to inserts changes nothing on show.
    final other = batch.any(
      (u) => u.kind != UpdateKind.insert && u.kind != UpdateKind.update,
    );
    if (other) _onlyInserts = false;
    _timer ??= Timer(historyPlaysDebounce, () {
      _timer = null;
      if (!_onlyInserts) _mustApplyNow = true;
      _onlyInserts = true;
      state = state + 1;
    });
  }
}
