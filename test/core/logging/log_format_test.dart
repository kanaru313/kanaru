import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/log_format.dart';
import 'package:logging/logging.dart';

void main() {
  final header = RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3} ');

  test('writes time, level, logger and message on one line', () {
    final line = formatRecord(LogRecord(Level.WARNING, 'hello', 'player'));
    expect(line, matches(header));
    expect(line, endsWith(' WARNING player: hello'));
    expect(line, isNot(contains('\n')));
  });

  test('puts the error and each stack frame on indented lines', () {
    final stack = StackTrace.fromString(
      '#0 main (a.dart:1)\n#1 run (b.dart:2)',
    );
    final lines = formatRecord(
      LogRecord(Level.SEVERE, 'failed', 'mpris', StateError('boom'), stack),
    ).split('\n');
    expect(lines, hasLength(4));
    expect(lines[0], endsWith('SEVERE mpris: failed'));
    expect(lines[1], '  Bad state: boom');
    expect(lines[2], '  #0 main (a.dart:1)');
    expect(lines[3], '  #1 run (b.dart:2)');
  });

  test('escapes a newline that would fake a record', () {
    final line = formatRecord(
      LogRecord(
        Level.INFO,
        'song.mp3\n2026-01-01T00:00:00.000 SEVERE app: fake\r',
        'player',
      ),
    );
    expect(line.split('\n'), hasLength(1));
    expect(line, contains(r'song.mp3\n2026-01-01'));
    expect(line, endsWith(r'fake\r'));
  });

  test('escapes terminal escape sequences, C1 controls and DEL', () {
    final line = formatRecord(
      LogRecord(Level.INFO, 'a\x1b]52;c;ZXZpbA==\x07b\u009b\x7f\tc', 'mpv'),
    );
    expect(
      line,
      endsWith(
        r'a\x1b]52;c;ZXZpbA==\x07b\x9b\x7f'
        '\tc',
      ),
    );
    expect(line.codeUnits.where((u) => u < 0x20 && u != 0x09), isEmpty);
  });

  test('escapes controls inside the error and the stack trace', () {
    final lines = formatRecord(
      LogRecord(
        Level.SEVERE,
        'x',
        'app',
        'bad\x1b[31m\rerror',
        StackTrace.fromString('#0 f\x1b[0m'),
      ),
    ).split('\n');
    expect(lines[1], r'  bad\x1b[31m\rerror');
    expect(lines[2], r'  #0 f\x1b[0m');
  });

  test('escapes line separators, bidi controls and the byte order mark', () {
    final line = formatRecord(
      LogRecord(
        Level.INFO,
        'a\u2028b\u2029c\u202ed\u200fe\u2066f\ufeffg',
        'x\u202ay',
      ),
    );
    for (final code in [
      0x2028,
      0x2029,
      0x202e,
      0x200f,
      0x2066,
      0xfeff,
      0x202a,
    ]) {
      expect(line, isNot(contains(String.fromCharCode(code))));
    }
    expect(line, contains(r'a\u2028b\u2029c\u202ed\u200fe\u2066f\ufeffg'));
    expect(line, contains(r'x\u202ay'));
  });

  test('an error or stack trace whose toString throws is replaced', () {
    final line = formatRecord(
      LogRecord(Level.SEVERE, 'bad', 'x', _Unprintable(), _UnprintableStack()),
    );
    expect(line, contains('\n  <unprintable _Unprintable>'));
    expect(line, contains('\n  <unprintable _UnprintableStack>'));
  });
}

class _Unprintable {
  @override
  String toString() => throw StateError('no');
}

class _UnprintableStack implements StackTrace {
  @override
  String toString() => throw StateError('no');
}
