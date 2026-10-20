import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/settings/settings_provider.dart';

/// Whether the app draws its own title bar (drag area + window buttons).
/// `false` by default so widget tests never touch the window plugin;
/// `main()` overrides it with the result of [setUpDesktopWindow].
final customTitleBarProvider = Provider<bool>((ref) => false);

/// Sets up the window for the chosen title bar and returns whether the app
/// must draw its own. Only [TitleBarPreference.kanaru] does.
///
/// [TitleBarPreference.system] keeps the native bar; on Wayland that is GTK's
/// header bar, which the runner always creates. [TitleBarPreference.none]
/// hides it without drawing a replacement.
Future<bool> setUpDesktopWindow({required TitleBarPreference titleBar}) async {
  if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    return false;
  }
  await windowManager.ensureInitialized();
  await windowManager.setTitleBarStyle(switch (titleBar) {
    TitleBarPreference.system => TitleBarStyle.normal,
    TitleBarPreference.kanaru ||
    TitleBarPreference.none => TitleBarStyle.hidden,
  });
  await windowManager.setMinimumSize(const Size(480, 720));
  return titleBar == TitleBarPreference.kanaru;
}

/// Brings the window back when the desktop asks (MPRIS `Raise`): shows it if
/// hidden, then un-minimizes and presents it. On Wayland compositors that
/// require xdg-activation (niri, for one) this has no visible effect: there
/// is no activation token to present with (SYS-15).
Future<void> raiseDesktopWindow() async {
  await windowManager.show();
  await windowManager.restore();
}
