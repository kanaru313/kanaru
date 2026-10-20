import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'log_format.dart';
import 'log_redaction.dart';
import 'repeated_error_filter.dart';
import 'rotating_log_file.dart';

final _log = Logger('app');

/// One logging session: the listener on `Logger.root` and the file sink.
/// Made by `setUpLogging`.
///
/// Where a record goes: the file; the console in debug builds; stderr for
/// WARNING and above when neither takes it (a release build whose file
/// cannot be opened), so a failure is never lost without a trace. Everything
/// is redacted first.
class LogSession {
  LogSession(
    this.directory,
    this._file,
    this._toConsole, {
    void Function(String line)? stderrLine,
  }) : _stderrLine = stderrLine ?? stderr.writeln {
    _subscription = Logger.root.onRecord.listen(write);
  }

  /// Directory that holds the log files, `null` when none could be found.
  final String? directory;

  final RotatingLogFile? _file;
  final bool _toConsole;
  final void Function(String line) _stderrLine;
  late final StreamSubscription<LogRecord> _subscription;
  late final RepeatedErrorFilter _repeats = RepeatedErrorFilter(
    onSummary: _writeRepeatSummary,
  );
  bool _writeToFile = true;
  bool _closed = false;

  bool _handlersInstalled = false;
  FlutterExceptionHandler? _previousFlutterHandler;
  ErrorCallback? _previousPlatformHandler;

  /// The file being written, `null` when logging to file is off.
  String? get filePath => _writeToFile ? _file?.path : null;

  /// Logs uncaught errors with their stack traces instead of letting them
  /// go unrecorded. Covers errors in the framework (build, layout, gestures)
  /// and errors that reach the root zone, such as a failing provider in a
  /// `ProviderContainer` made outside `ProviderScope`. The app keeps running.
  ///
  /// The errors are written whatever `KANARU_LOG_LEVEL` says: they are the
  /// records that matter most. With [presentErrors] the framework also
  /// prints every one of them to the console, unredacted, which is for debug
  /// builds: in a release build that output goes to the desktop's journal.
  /// Only the file folds repeats.
  void installErrorHandlers({bool presentErrors = kDebugMode}) {
    if (_closed || _handlersInstalled) return;
    _handlersInstalled = true;
    _previousFlutterHandler = FlutterError.onError;
    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    FlutterError.onError = (details) {
      if (_isNew(details.exception, details.stack)) {
        write(
          LogRecord(
            Level.SEVERE,
            'Uncaught error in ${details.library ?? 'Flutter'}',
            _log.name,
            details.exception,
            details.stack,
          ),
        );
      }
      // Folding limits the file, not the console: a developer who watches a
      // repeating error must still see it.
      if (presentErrors) FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (_isNew(error, stack)) {
        write(
          LogRecord(Level.SHOUT, 'Uncaught error', _log.name, error, stack),
        );
      }
      return true;
    };
  }

  /// Whether an uncaught error is to be written; a repeat of a recent one
  /// within the window is only counted. Never throws: on failure the error
  /// is written.
  bool _isNew(Object error, StackTrace? stack) {
    try {
      final (:key, :label) = RepeatedErrorFilter.describe(error, stack);
      return _repeats.shouldWrite(key, label: label);
    } catch (_) {
      return true;
    }
  }

  /// The "repeated ×N" record goes through [write], like any other record.
  void _writeRepeatSummary(String summary) {
    write(LogRecord(Level.SEVERE, summary, _log.name));
  }

  /// Stops listening, closes the file and puts back the error handlers that
  /// were there before [installErrorHandlers].
  Future<void> close() async {
    if (_closed) return;
    // Before `_closed`: `write` ignores records once closed.
    _repeats.close().forEach(_writeRepeatSummary);
    _closed = true;
    if (_handlersInstalled) {
      FlutterError.onError = _previousFlutterHandler;
      PlatformDispatcher.instance.onError = _previousPlatformHandler;
    }
    _file?.close();
    await _subscription.cancel();
  }

  /// Writes [record], whatever the level of `Logger.root`.
  ///
  /// Runs synchronously inside `Logger.log` (the record stream is a sync
  /// broadcast stream), so it must never throw, and never log through
  /// `Logger`: a nested log makes the stream throw a `StateError`. A record
  /// that cannot be written costs that record only; the file is switched
  /// off only when it fails.
  void write(LogRecord record) {
    if (_closed) return;
    try {
      final line = redactSecrets(formatRecord(record));
      if (_toConsole) debugPrint(line);
      final file = _file;
      if (_writeToFile && file != null) {
        if (file.write(line)) return;
        fileUnavailable(file.failure);
      }
      if (!_toConsole && record.level >= Level.WARNING) _stderrLine(line);
    } catch (error) {
      // Not `report`: whatever failed may fail again.
      _stderrSafely('Kanaru logging failed: ${error.runtimeType}');
    }
  }

  /// Stops writing to the file, which could not be opened or failed on a
  /// write, and says why.
  void fileUnavailable(Object? failure) {
    _writeToFile = false;
    report('Logging to file is off', failure);
  }

  /// A problem with logging itself, such as a log file that cannot be
  /// opened. Bypasses `Logger` on purpose.
  void report(String message, [Object? error]) {
    var detail = '';
    if (error != null) {
      try {
        detail = ': $error';
      } catch (_) {
        detail = ': ${error.runtimeType}';
      }
    }
    final line = redactSecrets(escapeControlCharacters('$message$detail'));
    if (_toConsole) {
      debugPrint(line);
    } else {
      _stderrSafely(line);
    }
  }

  void _stderrSafely(String line) {
    try {
      _stderrLine(line);
    } catch (_) {}
  }
}
