import 'package:logging/logging.dart';

/// One record as text: `2026-10-18T21:04:05.123 WARNING player: message`.
///
/// The message stays on one line. The error and the stack trace follow on
/// their own lines, each indented by two spaces, so a continuation line can
/// never be mistaken for a new record. Control characters are escaped
/// everywhere (see [escapeControlCharacters]), so a file name or a line from
/// mpv cannot fake a record or send escape sequences to a terminal.
String formatRecord(LogRecord record) {
  final out = StringBuffer()
    ..write(_timestamp(record.time))
    ..write(' ')
    ..write(record.level.name)
    ..write(' ')
    ..write(escapeControlCharacters(record.loggerName))
    ..write(': ')
    ..write(escapeControlCharacters(record.message));
  final error = record.error;
  if (error != null) _writeIndented(out, _describe(error));
  final stack = record.stackTrace;
  if (stack != null) _writeIndented(out, _describe(stack));
  return out.toString();
}

/// `toString` of an error from anywhere, including code whose `toString`
/// throws: one odd error must not cost the record, or the sink.
String _describe(Object value) {
  try {
    return value.toString();
  } catch (_) {
    return '<unprintable ${value.runtimeType}>';
  }
}

/// Replaces CR, LF and the other C0/C1 control characters (and DEL) with a
/// visible escape such as `\n` or `\x1b`. Tab is kept. Unicode line and
/// paragraph separators, bidirectional controls (they reorder text in a
/// viewer, so a line can look like another) and the byte order mark are
/// escaped as `\u2028` and so on.
String escapeControlCharacters(String text) {
  if (!_control.hasMatch(text)) return text;
  return text.replaceAllMapped(_control, (match) {
    final unit = match[0]!.codeUnitAt(0);
    return switch (unit) {
      0x0a => r'\n',
      0x0d => r'\r',
      < 0x100 => '\\x${unit.toRadixString(16).padLeft(2, '0')}',
      _ => '\\u${unit.toRadixString(16).padLeft(4, '0')}',
    };
  });
}

final _control = RegExp(
  '[\x00-\x08\x0a-\x1f\x7f-\x9f\u2028\u2029\u200e\u200f'
  '\u202a-\u202e\u2066-\u2069\ufeff]',
);

void _writeIndented(StringBuffer out, String text) {
  for (final line in text.trimRight().split('\n')) {
    out
      ..write('\n  ')
      ..write(escapeControlCharacters(line));
  }
}

String _timestamp(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${time.year.toString().padLeft(4, '0')}-${two(time.month)}-'
      '${two(time.day)}T${two(time.hour)}:${two(time.minute)}:'
      '${two(time.second)}.${time.millisecond.toString().padLeft(3, '0')}';
}
