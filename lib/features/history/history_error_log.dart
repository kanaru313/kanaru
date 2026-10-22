// The only way to reach the SQLite error behind a failure in the database
// isolate; `remoteCause` is read for its codes only.
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

final _log = Logger('history');

/// The type of [error] and, for a SQLite error, its code. Never the message:
/// SQLite puts the statement's parameters in it, and for the history those
/// are file paths.
String describeHistoryError(Object error) {
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  if (cause is SqliteException) {
    return '${cause.runtimeType} ${cause.extendedResultCode}';
  }
  return '${cause.runtimeType}';
}

/// Logs that [what] failed with [error], described by [describeHistoryError].
void logHistoryError(String what, Object error) =>
    _log.warning('$what: ${describeHistoryError(error)}');
