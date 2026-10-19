import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/shell/window/desktop_window.dart';
import 'core/media_controls/media_controls_provider.dart';
import 'core/media_controls/mpris/mpris_media_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final customTitleBar = await setUpDesktopWindow();

  final container = ProviderContainer(
    overrides: [
      customTitleBarProvider.overrideWithValue(customTitleBar),
      if (Platform.isLinux)
        mediaControlsProvider.overrideWith((ref) {
          final controls = MprisMediaControls(
            ref,
            DBusClient.session(),
            onRaise: raiseDesktopWindow,
          );
          ref.onDispose(controls.dispose);
          return controls;
        }),
    ],
  );
  // Media controls live for the whole session. A container listener, unlike
  // a widget's watch, is never paused, so the provider's own state listener
  // keeps publishing changes even when the UI is not ticking.
  container.listen(mediaControlsProvider, (_, _) {});

  runApp(
    UncontrolledProviderScope(container: container, child: const KanaruApp()),
  );
}
