import 'dart:async';

import 'package:drift/drift.dart'
    show TableUpdate, TableUpdateQuery, UpdateKind;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/library_startup.dart';
import '../../shared/library_browse_refresh.dart';

/// How long changes to `plays` are collected before the page reads again.
const homePlaysDebounce = Duration(milliseconds: 250);

/// The current local time. Tests replace it to pin the day.
final homeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Whether a batch of `plays` updates changes what the page shows. The
/// recorder checkpoints `listened_ms` with plain updates about every 30
/// seconds, which no shelf shows; any other kind counts, and so does an
/// update with no kind (a custom statement), as nothing says what it did.
/// Same rule as the one the history page applies to its own reads.
bool homeBatchChangesRows(Set<TableUpdate> batch) =>
    batch.any((u) => u.kind != UpdateKind.update);

/// A number that goes up when what the Home page shows may have changed: the
/// one signal every section provider reads again on.
///
/// It goes up when
/// - plays are added or removed (collected for [homePlaysDebounce], so a
///   batch of inserts bumps once; checkpoint updates are ignored),
/// - `tracks` changed (a scan): the first change bumps at once, the ones
///   inside `libraryBrowseRefreshIntervalProvider` become a single bump at
///   the end of the interval,
/// - the local day turns over, as the memories and the added-at windows
///   follow the date.
///
/// Without a library nothing is subscribed and no timer runs.
final homeDataVersionProvider =
    NotifierProvider.autoDispose<HomeDataVersion, int>(HomeDataVersion.new);

class HomeDataVersion extends Notifier<int> {
  Timer? _playsTimer;
  Timer? _cooldown;
  Timer? _midnight;
  var _tracksDirty = false;

  @override
  int build() {
    final db = ref.watch(libraryDatabaseProvider);
    final interval = ref.watch(libraryBrowseRefreshIntervalProvider);
    final clock = ref.watch(homeClockProvider);
    // The notifier object is reused when the provider rebuilds, so leave
    // nothing behind that the next build would take for its own.
    ref.onDispose(() {
      _playsTimer?.cancel();
      _cooldown?.cancel();
      _midnight?.cancel();
      _playsTimer = null;
      _cooldown = null;
      _midnight = null;
      _tracksDirty = false;
    });
    if (db == null) return 0;

    final plays = db
        .tableUpdates(TableUpdateQuery.onTable(db.plays))
        .listen(_onPlays);
    final tracks = db
        .tableUpdates(TableUpdateQuery.onTable(db.tracks))
        .listen((_) => _onTracks(interval));
    ref.onDispose(plays.cancel);
    ref.onDispose(tracks.cancel);
    _armMidnight(clock);
    return 0;
  }

  void _onPlays(Set<TableUpdate> batch) {
    if (!homeBatchChangesRows(batch)) return;
    _playsTimer ??= Timer(homePlaysDebounce, () {
      _playsTimer = null;
      state = state + 1;
    });
  }

  void _onTracks(Duration interval) {
    if (_cooldown != null) {
      _tracksDirty = true;
      return;
    }
    state = state + 1;
    if (interval <= Duration.zero) return;
    _cooldown = Timer(interval, () {
      _cooldown = null;
      if (!_tracksDirty) return;
      _tracksDirty = false;
      _onTracks(interval);
    });
  }

  void _armMidnight(DateTime Function() clock) {
    final now = clock();
    final next = DateTime(now.year, now.month, now.day + 1);
    var wait = next.difference(now);
    if (wait <= Duration.zero) wait = const Duration(seconds: 1);
    _midnight = Timer(wait, () {
      state = state + 1;
      _armMidnight(clock);
    });
  }
}
