import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'log_directory.dart';
import 'log_format.dart';
import 'log_level.dart';
import 'log_session.dart';
import 'rotating_log_file.dart';

export 'log_session.dart' show LogSession;

/// App version for the session header, set at build time with
/// `--dart-define=KANARU_VERSION=<version>`.
const kanaruVersion = String.fromEnvironment(
  'KANARU_VERSION',
  defaultValue: 'dev',
);

final _log = Logger('app');

LogSession? _active;

/// Sends every `package:logging` record to the log file (and the console in
/// debug builds). Never throws: when the file cannot be opened, logging goes
/// on without it and the reason is printed to the console or stderr.
///
/// Calling it again closes the previous session first, so there is only ever
/// one listener. (A hot restart resets the statics, so this does not help
/// there.)
LogSession setUpLogging({
  Map<String, String>? environment,
  bool console = kDebugMode,
  Level defaultLevel = kDebugMode ? Level.ALL : Level.INFO,
  @visibleForTesting void Function(String line)? stderrLine,
}) {
  unawaited(_active?.close());
  final env = environment ?? Platform.environment;
  final rawLevel = env['KANARU_LOG_LEVEL'];
  final level = parseLogLevel(rawLevel, fallback: defaultLevel);
  Logger.root.level = level;

  // Not subject to the level, so every file says who wrote it.
  final headerRecord = LogRecord(
    Level.INFO,
    'Kanaru $kanaruVersion on ${Platform.operatingSystem} '
        '${Platform.operatingSystemVersion}, pid $pid, level ${level.name}',
    'app',
  );
  final directory = resolveLogDirectory(env);
  final file = directory == null
      ? null
      : RotatingLogFile(directory, header: formatRecord(headerRecord));
  final session = LogSession(directory, file, console, stderrLine: stderrLine);
  _active = session;
  if (directory == null) {
    session.report(
      'Logging to file is off: neither XDG_CACHE_HOME nor HOME '
      'is an absolute path',
    );
  } else if (!file!.open()) {
    session.fileUnavailable(file.failure);
  }

  session.write(headerRecord);
  if (rawLevel != null &&
      rawLevel.trim().isNotEmpty &&
      level.name != rawLevel.trim().toUpperCase()) {
    _log.warning('Unknown KANARU_LOG_LEVEL "$rawLevel", using ${level.name}');
  }
  return session;
}
