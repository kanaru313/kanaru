import 'package:logging/logging.dart';

/// Parses a `KANARU_LOG_LEVEL` value: a `Level` name of `package:logging`
/// (`ALL`, `FINEST` … `SHOUT`, `OFF`), in any case. Returns [fallback] for a
/// missing, empty or unknown value; the caller decides whether to warn.
Level parseLogLevel(String? raw, {required Level fallback}) {
  final name = raw?.trim().toUpperCase();
  if (name == null || name.isEmpty) return fallback;
  for (final level in Level.LEVELS) {
    if (level.name == name) return level;
  }
  return fallback;
}
