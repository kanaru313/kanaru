import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'open_external.dart';
export 'open_external.dart' show ProcessStarter;

/// Shows a file in the desktop's file manager. Returns `false` when nothing
/// could open it, so the caller can tell the user.
final showInFileManagerProvider = Provider<Future<bool> Function(String path)>(
  (ref) =>
      (path) => showInFileManager(path),
);

/// How long to wait for the file manager to answer over D-Bus. A timeout
/// counts as success: the service exists and is starting (activation can be
/// slow), and it will still receive the call, so opening the folder too would
/// give two windows.
const _dbusTimeout = Duration(seconds: 3);

/// Asks `org.freedesktop.FileManager1` to show [filePath] selected; if that
/// fails with a D-Bus error (no such service, no session bus, ...), opens
/// its folder with [openExternal]. `false` means D-Bus failed and neither
/// opener worked.
Future<bool> showInFileManager(
  String filePath, {
  Future<void> Function(String uri)? showItems,
  ProcessStarter start = startInheritingStdio,
  Duration dbusTimeout = _dbusTimeout,
  Duration timeout = openerTimeout,
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
  return openExternal(
    File(filePath).parent.path,
    start: start,
    timeout: timeout,
  );
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
