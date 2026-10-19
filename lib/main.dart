import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/shell/window/desktop_window.dart';
import 'core/logging/app_logging.dart';
import 'core/media_controls/media_controls_provider.dart';
import 'core/media_controls/mpris/mpris_media_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // First, so startup errors are logged too. Never throws.
  setUpLogging().installErrorHandlers();
  MediaKit.ensureInitialized();
  final customTitleBar = await setUpDesktopWindow();

  // Unlike ProviderScope, a container made here does not route uncaught
  // provider errors to FlutterError.reportError (its onError is internal);
  // they reach the root zone, where PlatformDispatcher.onError logs them.
  final container = ProviderContainer(
    overrides: [
      customTitleBarProvider.overrideWithValue(customTitleBar),
      if (Platform.isLinux)
        mediaControlsProvider.overrideWith((ref) {
          final controls = MprisMediaControls(
            ref,
            DBusClient.session,
            onRaise: raiseDesktopWindow,
          );
          ref.onDispose(controls.dispose);
          return controls;
        }),
    ],
  );
  // Nothing in the UI reads the provider, so this listener is what creates
  // the media controls at startup. It also keeps them for the whole session.
  container.listen(mediaControlsProvider, (_, _) {});

  runApp(
    UncontrolledProviderScope(container: container, child: const KanaruApp()),
  );
}
