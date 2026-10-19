import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starts a process; swapped out in tests.
typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments,
);

/// Opens a folder path or `https://` URL in the desktop's default app.
/// Returns `false` when nothing could open it, so the caller can tell the user.
final openExternalProvider = Provider<Future<bool> Function(String target)>(
  (ref) =>
      (target) => openExternal(target),
);

const _openers = [
  ['gio', 'open'],
  ['xdg-open'],
];

/// How long to wait for an opener to hand the target over to an app. Both
/// openers return right away once they have; a timeout counts as success.
const _openerTimeout = Duration(seconds: 5);

/// Tries `gio open`, then `xdg-open`. Arguments are passed as a list, never
/// through a shell, and targets always start with `/` or `https://`, so they
/// can't be read as options.
Future<bool> openExternal(
  String target, {
  ProcessStarter start = _start,
  Duration timeout = _openerTimeout,
}) async {
  for (final [executable, ...arguments] in _openers) {
    try {
      final process = await start(executable, [...arguments, target]);
      // Unread output could fill the pipe and block the opener.
      unawaited(process.stdout.drain<void>().then((_) {}, onError: (_) {}));
      unawaited(process.stderr.drain<void>().then((_) {}, onError: (_) {}));
      final code = await process.exitCode.timeout(timeout, onTimeout: () => 0);
      if (code == 0) return true;
    } on ProcessException {
      // This opener isn't installed: try the next one.
    }
  }
  return false;
}

/// Creates [path] if missing, then opens it. `false` if it can't be created.
Future<bool> openDirectory(
  String path, {
  Future<bool> Function(String target)? open,
}) async {
  try {
    await Directory(path).create(recursive: true);
  } on FileSystemException {
    return false;
  }
  return (open ?? openExternal)(path);
}

Future<Process> _start(String executable, List<String> arguments) =>
    Process.start(executable, arguments);
