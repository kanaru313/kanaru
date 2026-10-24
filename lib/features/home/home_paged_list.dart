import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../core/database/library_database.dart';
import '../../core/database/library_startup.dart';
import 'home_data_version.dart';

final _log = Logger('home');

/// Rows read per page of a full list.
const homePageSize = 200;

/// Reads `limit` rows of a list starting at `offset`. [now] is the clock of
/// the page, for windows that follow the date.
typedef HomePageReader<T> = Future<List<T>> Function(
  LibraryDatabase db,
  DateTime now,
  int limit,
  int offset,
);

/// What a full list has loaded so far.
class HomePagedState<T> {
  const HomePagedState({
    this.rows = const [],
    this.done = false,
    this.loading = true,
    this.failed = false,
  });

  /// Rows loaded, in order, without repeats.
  final List<T> rows;

  /// The last page came back short: there is nothing more to read.
  final bool done;

  /// A read is running.
  final bool loading;

  /// The last read failed; nothing reads again until the data changes or
  /// [HomePagedList.retry] is called.
  final bool failed;

  HomePagedState<T> copyWith({
    List<T>? rows,
    bool? done,
    bool? loading,
    bool? failed,
  }) => HomePagedState(
    rows: rows ?? this.rows,
    done: done ?? this.done,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
  );
}

/// A list read page by page as the user scrolls, with no cap. When the Home
/// data changes it reads again, in one query, every row loaded so far and
/// swaps them in, so the list neither empties nor jumps.
class HomePagedList<T> extends Notifier<HomePagedState<T>> {
  HomePagedList({required this.read, required this.keyOf});

  final HomePageReader<T> read;

  /// Identity of a row, to drop one that two pages both returned because the
  /// data shifted between the reads.
  final Object Function(T row) keyOf;

  /// Goes up whenever a newer read makes the one in flight stale.
  var _generation = 0;
  LibraryDatabase? _db;

  @override
  HomePagedState<T> build() {
    _db = ref.watch(libraryDatabaseProvider);
    ref.listen(homeDataVersionProvider, (_, _) => unawaited(_reload()));
    ref.onDispose(() => _generation++);
    if (_db == null) return HomePagedState<T>(done: true, loading: false);
    scheduleMicrotask(_loadPage);
    return HomePagedState<T>();
  }

  Future<List<T>> _read(int limit, int offset) =>
      read(_db!, ref.read(homeClockProvider)(), limit, offset);

  /// Reads the next page. Does nothing while a read runs, after the end or
  /// after a failure.
  Future<void> loadMore() async {
    if (state.loading) return;
    await _loadPage();
  }

  /// Reads again after a failure: clears the failure and reads the next page.
  /// Does nothing unless the last read failed.
  Future<void> retry() async {
    if (state.loading || !state.failed) return;
    state = state.copyWith(failed: false);
    await _loadPage();
  }

  Future<void> _loadPage() async {
    final db = _db;
    if (db == null || !ref.mounted) return;
    final current = state;
    if (current.done || current.failed) return;
    final generation = ++_generation;
    state = current.copyWith(loading: true);
    try {
      final page = await _read(homePageSize, current.rows.length);
      if (generation != _generation || !ref.mounted) return;
      final seen = {for (final row in current.rows) keyOf(row)};
      state = current.copyWith(
        rows: [
          ...current.rows,
          for (final row in page)
            if (seen.add(keyOf(row))) row,
        ],
        done: page.length < homePageSize,
        loading: false,
      );
    } on Object catch (error) {
      // Only the type: SQLite puts the statement's parameters in a message.
      _log.warning('Reading a Home list failed: ${error.runtimeType}');
      if (generation != _generation || !ref.mounted) return;
      state = current.copyWith(loading: false, failed: true);
    }
  }

  Future<void> _reload() async {
    final db = _db;
    if (db == null || !ref.mounted) return;
    final generation = ++_generation;
    final current = state;
    final count = current.rows.length < homePageSize
        ? homePageSize
        : current.rows.length;
    state = current.copyWith(loading: true, failed: false);
    try {
      final rows = await _read(count, 0);
      if (generation != _generation || !ref.mounted) return;
      final seen = <Object>{};
      state = HomePagedState(
        rows: [
          for (final row in rows)
            if (seen.add(keyOf(row))) row,
        ],
        done: rows.length < count,
        loading: false,
      );
    } on Object catch (error) {
      _log.warning('Reading a Home list failed: ${error.runtimeType}');
      if (generation != _generation || !ref.mounted) return;
      // Keep what is shown; the next change reads again.
      state = current.copyWith(loading: false, failed: true);
    }
  }
}
