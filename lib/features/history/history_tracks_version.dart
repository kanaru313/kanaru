import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_startup.dart';
import '../../shared/library_browse_refresh.dart';

/// A number that goes up when `tracks` changed (a scan), so rows that carry
/// track tags are read again. At most one bump per
/// `libraryBrowseRefreshIntervalProvider`: the first change bumps at once, the
/// ones inside the interval become a single bump at its end, so a scan does
/// not make the page read after every batch.
final historyTracksVersionProvider =
    NotifierProvider.autoDispose<HistoryTracksVersion, int>(
      HistoryTracksVersion.new,
    );

class HistoryTracksVersion extends Notifier<int> {
  Timer? _cooldown;
  var _dirty = false;

  @override
  int build() {
    final db = ref.watch(libraryDatabaseProvider);
    final interval = ref.watch(libraryBrowseRefreshIntervalProvider);
    ref.onDispose(() => _cooldown?.cancel());
    if (db != null) {
      final updates = db
          .tableUpdates(TableUpdateQuery.onTable(db.tracks))
          .listen((_) => _changed(interval));
      ref.onDispose(updates.cancel);
    }
    return 0;
  }

  void _changed(Duration interval) {
    if (_cooldown != null) {
      _dirty = true;
      return;
    }
    state = state + 1;
    if (interval <= Duration.zero) return;
    _cooldown = Timer(interval, () {
      _cooldown = null;
      if (!_dirty) return;
      _dirty = false;
      _changed(interval);
    });
  }
}
