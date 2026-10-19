// Run as a separate process by rotating_log_file_test.dart: a lock taken by
// the test process itself would not block a second open in that process.
import 'dart:convert';
import 'dart:io';

import 'package:kanaru/core/logging/rotating_log_file.dart';

/// Holds the shared log set of the directory in `args[0]`. Prints `ready`
/// once it owns it; on a `fill` line writes enough to rotate mid-session and
/// prints `rotated`. Exits when stdin closes.
Future<void> main(List<String> args) async {
  final file = RotatingLogFile(args[0], maxBytes: 200);
  if (!file.open() || !file.ownsSharedSet) {
    stdout.writeln('failed: ${file.failure}');
    exit(1);
  }
  file.write('holder first');
  stdout.writeln('ready');
  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line == 'fill') {
      file.write('x' * 300);
      stdout.writeln('rotated');
    }
  }
  file.close();
}
