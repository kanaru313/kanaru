import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// Whether the app draws its own title bar (drag area + window buttons).
/// `false` by default so widget tests never touch the window plugin;
/// `main()` overrides it with the result of [setUpDesktopWindow].
final customTitleBarProvider = Provider<bool>((ref) => false);

/// Hides the native title bar on desktop platforms. Returns whether the app
/// must draw its own.
Future<bool> setUpDesktopWindow() async {
  if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    return false;
  }
  await windowManager.ensureInitialized();
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  await windowManager.setMinimumSize(const Size(480, 360));
  return true;
}

/// Brings the window back when the desktop asks (MPRIS `Raise`): shows it if
/// hidden, then un-minimizes and presents it. Wayland compositors may only
/// mark it as wanting attention.
Future<void> raiseDesktopWindow() async {
  await windowManager.show();
  await windowManager.restore();
}
