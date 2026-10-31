import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens an `https://` address in the desktop's default app. Returns `false`
/// when nothing could open it. Swapped out in tests.
final lyricsSourcesOpenUrlProvider =
    Provider<Future<bool> Function(String url)>((ref) => _openUrl);

const _openers = [
  ['gio', 'open'],
  ['xdg-open'],
];

/// Both openers return at once after handing the address to an app, so a
/// timeout counts as success.
const _openerTimeout = Duration(seconds: 2);

/// Tries `gio open`, then `xdg-open`. Arguments go as a list, never through a
/// shell, and the address always starts with `https://`, so it cannot read
/// as an option.
Future<bool> _openUrl(String url) async {
  if (!url.startsWith('https://')) return false;
  for (final [executable, ...arguments] in _openers) {
    try {
      final process = await Process.start(executable, [
        ...arguments,
        url,
      ], mode: ProcessStartMode.inheritStdio);
      final code = await process.exitCode.timeout(
        _openerTimeout,
        onTimeout: () => 0,
      );
      if (code == 0) return true;
    } on ProcessException {
      // This opener is not installed: try the next one.
    }
  }
  return false;
}
