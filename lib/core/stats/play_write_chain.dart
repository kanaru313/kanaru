// The only way to reach the SQLite error behind a failure in the database
// isolate; `remoteCause` is read for its codes only.
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

final _log = Logger('listen_recorder');

/// Runs the play history writes one after another, so a later write sees the
/// effect of the earlier ones. A failed write is logged, never thrown.
class PlayWriteChain {
  Future<void> _tail = Future.value();

  /// Completes when every queued write has finished.
  Future<void> get idle => _tail;

  /// Appends [op] to the chain. A failure is logged without the error object
  /// (its text carries the statement parameters, so the track path) and
  /// completes with `null`. Catches `Object` because a closed drift
  /// connection throws an `Error`.
  Future<T?> enqueue<T>(Future<T> Function() op) {
    final result = _tail.then<T?>((_) async {
      try {
        return await op();
      } on Object catch (error) {
        _log.warning('Could not write the play history: ${_describe(error)}');
        return null;
      }
    });
    _tail = result.then((_) {});
    return result;
  }

  /// Error type and SQLite codes only; never the message of a statement.
  static String _describe(Object error) {
    final cause = error is DriftRemoteException ? error.remoteCause : error;
    if (cause is SqliteException) {
      return '${cause.runtimeType} ${cause.extendedResultCode} '
          '${cause.message}';
    }
    return '${cause.runtimeType}';
  }
}
