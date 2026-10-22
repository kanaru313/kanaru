import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/history/history_error_log.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

const _secret = '/home/someone/Music/secret-song.flac';

void main() {
  test('a SQLite error is described by type and code alone', () {
    final error = SqliteException(
      extendedResultCode: 1555,
      message: 'UNIQUE constraint failed: plays.id ($_secret)',
      causingStatement: 'INSERT INTO plays VALUES (?)',
      parametersToStatement: [_secret],
    );

    final text = describeHistoryError(error);

    expect(text, 'SqliteException 1555');
    expect(text, isNot(contains(_secret)));
  });

  test('another error is described by its type only', () {
    expect(describeHistoryError(StateError(_secret)), 'StateError');
    expect(describeHistoryError(FormatException(_secret)), 'FormatException');
  });

  test('the log line carries no path', () {
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);
    final level = Logger.root.level;
    Logger.root.level = Level.ALL;
    addTearDown(() => Logger.root.level = level);

    logHistoryError(
      'Removing a play failed',
      SqliteException(extendedResultCode: 8, message: 'readonly: $_secret'),
    );
    logHistoryError('Reading failed', StateError(_secret));

    expect(records, hasLength(2));
    for (final r in records) {
      expect(r.message, isNot(contains(_secret)));
      expect(r.error, isNull);
      expect(r.stackTrace, isNull);
    }
    expect(records.first.message, 'Removing a play failed: SqliteException 8');
  });
}
