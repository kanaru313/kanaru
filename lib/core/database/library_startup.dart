import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart';

import '../paths/app_directories.dart';
import 'library_database.dart';

final _log = Logger('library');

/// The open library database, or `null` when it is unavailable (it failed to
/// open at startup). Every consumer must treat `null` as "no library".
/// [LibraryStartup.overrides] supplies the real value; tests override it with
/// `LibraryDatabase(NativeDatabase.memory())`.
final libraryDatabaseProvider = Provider<LibraryDatabase?>((ref) => null);

/// Whether at least one library root exists; the router uses it to show the
/// first-run source picker. Seeded from [LibraryStartup.hasRoots]; whoever
/// adds the first root calls [LibraryHasRoots.markPresent]. Lives here, next
/// to the database provider, so `LibraryStartup.overrides` can seed it
/// without `core/database` importing `core/indexer`.
class LibraryHasRoots extends Notifier<bool> {
  LibraryHasRoots([this._initial = false]);

  final bool _initial;

  @override
  bool build() => _initial;

  void markPresent() => state = true;
}

final libraryHasRootsProvider = NotifierProvider<LibraryHasRoots, bool>(
  LibraryHasRoots.new,
);

/// Outcome of [openLibraryAtStartup].
class LibraryStartup {
  const LibraryStartup({this.db, this.hasRoots = false, this.error});

  /// The opened database; `null` when opening failed.
  final LibraryDatabase? db;

  /// Whether at least one library root is stored. `false` when [db] is null.
  final bool hasRoots;

  /// Why the library is unavailable; `null` on success.
  final String? error;

  /// Provider overrides to pass to the root `ProviderContainer`.
  List<Override> get overrides => [
    libraryDatabaseProvider.overrideWithValue(db),
    libraryHasRootsProvider.overrideWith(() => LibraryHasRoots(hasRoots)),
  ];
}

/// Runs once per connection on the database isolate, so it captures no state.
/// WAL lets the UI read while a scan writes.
void applyLibraryPragmas(Database rawDb) {
  rawDb.execute('PRAGMA journal_mode = WAL;');
  rawDb.execute('PRAGMA synchronous = NORMAL;');
  rawDb.execute('PRAGMA foreign_keys = ON;');
  rawDb.execute('PRAGMA busy_timeout = 5000;');
}

/// Opens `library.db` in the data directory and runs the first query, which
/// is when drift really opens the file (PRAGMAs and migrations run then).
///
/// Never throws and never deletes or renames the file: a missing data
/// directory, a corrupt file, a database newer than this app, bad
/// permissions, a full disk or a [timeout] all give a result with `db == null`
/// and an [LibraryStartup.error]. Playback does not depend on the library.
Future<LibraryStartup> openLibraryAtStartup(
  Map<String, String> environment, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  LibraryDatabase? db;
  try {
    final dataDir = resolveDataDirectory(environment);
    if (dataDir == null) {
      throw StateError('no data directory: HOME and XDG_DATA_HOME are unset');
    }
    await Directory(dataDir).create(recursive: true);
    final file = File('$dataDir/library.db');
    final opened = db = LibraryDatabase(
      NativeDatabase.createInBackground(file, setup: applyLibraryPragmas),
    );
    final hasRoots = await opened.hasLibraryRoots().timeout(timeout);
    return LibraryStartup(db: opened, hasRoots: hasRoots);
  } catch (error, stackTrace) {
    _log.severe('Library database unavailable', error, stackTrace);
    if (db != null) {
      try {
        await db.close().timeout(const Duration(seconds: 2));
      } catch (closeError) {
        _log.warning('Closing the library database failed', closeError);
      }
    }
    return LibraryStartup(error: error.toString());
  }
}
