import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starts a process with inherited stdio (no pipes to drain); swapped out in
/// tests.
typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments,
);

/// Shows a file in the desktop's file manager. Returns `false` when nothing
/// could open it, so the caller can tell the user.
final showInFileManagerProvider = Provider<Future<bool> Function(String path)>(
  (ref) =>
      (path) => showInFileManager(path),
);

const _openers = [
  ['gio', 'open'],
  ['xdg-open'],
];

/// How long to wait for the file manager to answer over D-Bus, and for an
/// opener to hand the folder over to an app. A D-Bus timeout counts as
/// success: the service exists and is starting (activation can be slow), and
/// it will still receive the call, so opening the folder too would give two
/// windows. A timeout of an opener counts as success as well: both openers
/// return right away once they have handed the folder over.
const _dbusTimeout = Duration(seconds: 3);
const _openerTimeout = Duration(seconds: 2);

/// Asks `org.freedesktop.FileManager1` to show [filePath] selected; if that
/// fails with a D-Bus error (no such service, no session bus, ...), opens
/// its folder with `gio open`, then `xdg-open`. Arguments are passed as a
/// list, never through a shell. `false` means D-Bus failed and neither
/// opener worked.
Future<bool> showInFileManager(
  String filePath, {
  Future<void> Function(String uri)? showItems,
  ProcessStarter start = _start,
  Duration dbusTimeout = _dbusTimeout,
  Duration timeout = _openerTimeout,
}) async {
  try {
    await (showItems ?? _showItems)(Uri.file(filePath).toString())
        .timeout(dbusTimeout);
    return true;
  } on TimeoutException {
    // Still starting; see [_dbusTimeout].
    return true;
  } on Object {
    // No file manager on the bus, or it refused the call: open the folder.
  }
  final directory = File(filePath).parent.path;
  for (final [executable, ...arguments] in _openers) {
    try {
      final process = await start(executable, [...arguments, directory]);
      final code = await process.exitCode.timeout(timeout, onTimeout: () => 0);
      if (code == 0) return true;
    } on ProcessException {
      // This opener isn't installed: try the next one.
    }
  }
  return false;
}

Future<void> _showItems(String uri) async {
  final client = DBusClient.session();
  try {
    await client.callMethod(
      destination: 'org.freedesktop.FileManager1',
      path: DBusObjectPath('/org/freedesktop/FileManager1'),
      interface: 'org.freedesktop.FileManager1',
      name: 'ShowItems',
      values: [
        DBusArray.string([uri]),
        const DBusString(''),
      ],
    );
  } finally {
    await client.close();
  }
}

Future<Process> _start(String executable, List<String> arguments) =>
    Process.start(executable, arguments, mode: ProcessStartMode.inheritStdio);
