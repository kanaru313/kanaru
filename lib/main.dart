import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/shell/window/desktop_window.dart';
import 'core/database/library_startup.dart';
import 'core/indexer/library_startup_tasks.dart';
import 'core/logging/app_logging.dart';
import 'core/media_controls/media_controls_provider.dart';
import 'core/media_controls/mpris/mpris_media_controls.dart';
import 'core/paths/app_directories.dart' show resolveCoverCacheDirectory;
import 'core/player/app_exit_flush.dart';
import 'core/player/media_kit_backend.dart';
import 'core/player/original_cover_reader.dart';
import 'core/player/player_service.dart';
import 'core/player/rust_original_cover_reader.dart';
import 'core/player/session/playback_session_provider.dart';
import 'core/player/unavailable_audio_backend.dart';
import 'core/settings/settings_provider.dart';
import 'core/stats/listen_recorder_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // First, so startup errors are logged too. Never throws.
  setUpLogging().installErrorHandlers();
  final log = Logger('main');

  // Without libmpv the app still starts, in library-only mode (see
  // audioBackendOrUnavailable). Throwing here would leave the window hidden.
  var engineReady = true;
  try {
    MediaKit.ensureInitialized();
  } catch (error, stack) {
    engineReady = false;
    log.severe('Audio engine failed to initialise', error, stack);
  }

  // Settings come first: the title bar choice is applied while the window is
  // set up. Loading never throws; a missing or broken file means defaults.
  final settingsFile = settingsFileFor(Platform.environment);
  final settings = settingsFile?.load() ?? const AppSettings();

  // A window that cannot be set up falls back to the system title bar.
  var customTitleBar = false;
  // Whether window_manager is initialised (the setup's result says only
  // whether the custom bar is on); the exit hook needs it.
  var windowReady = false;
  try {
    customTitleBar = await setUpDesktopWindow(titleBar: settings.titleBar);
    windowReady = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  } catch (error, stack) {
    log.severe('Window setup failed', error, stack);
    // Setup may have hidden the native bar before failing.
    await restoreSystemTitleBar();
  }
  // Library database. Never throws: on failure the library is unavailable but
  // playback still works.
  final library = await openLibraryAtStartup(Platform.environment);

  // Unlike ProviderScope, a container made here does not route uncaught
  // provider errors to FlutterError.reportError (its onError is internal);
  // they reach the root zone, where PlatformDispatcher.onError logs them.
  final container = ProviderContainer(
    overrides: [
      initialSettingsProvider.overrideWithValue(settings),
      settingsFileProvider.overrideWithValue(settingsFile),
      customTitleBarProvider.overrideWithValue(customTitleBar),
      audioBackendOverride(
        engineReady: engineReady,
        create: MediaKitBackend.new,
      ),
      ...library.overrides,
      sessionCoverDirectoryProvider.overrideWithValue(
        resolveCoverCacheDirectory(Platform.environment),
      ),
      originalCoverReaderProvider.overrideWithValue(
        const RustOriginalCoverReader(),
      ),
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
  // Records listens (STAT-01) for the whole session; nothing in the UI keeps
  // it alive.
  container.listen(listenRecorderProvider, (_, _) {});

  runApp(
    UncontrolledProviderScope(container: container, child: const KanaruApp()),
  );
  // After the first frame, so the scan never delays the window appearing.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(runLibraryStartupTasks(container)),
  );
  if (windowReady) await _installExitHook(container, log);
}

/// Flushes the listen progress and the session when the window closes. Only
/// a window close gets here: SIGTERM, SIGKILL and a logout kill run nothing,
/// so the checkpoints (30 s for listens, 10 s for the session) bound the loss.
/// Installed after `runApp` so a crash before the first frame cannot leave a
/// close that nothing answers. Never throws: if it fails, closing works as
/// before.
Future<void> _installExitHook(ProviderContainer container, Logger log) async {
  try {
    // The listener goes first, so a prevented close always has a handler.
    windowManager.addListener(
      _ExitOnClose(
        exitOnClose(
          hide: windowManager.hide,
          pause: () => container.read(playerServiceProvider.notifier).pause(),
          flushSteps: [
            () =>
                container.read(listenRecorderProvider)?.flush() ??
                Future.value(),
            () => container.read(playerServiceProvider.notifier).flushSession(),
          ],
          destroy: windowManager.destroy,
          exit: () => exit(0),
        ),
      ),
    );
    await windowManager.setPreventClose(true);
  } catch (error, stack) {
    log.warning('Exit hook not installed', error, stack);
  }
}

class _ExitOnClose with WindowListener {
  _ExitOnClose(this._onClose);

  final Future<void> Function() _onClose;

  @override
  void onWindowClose() => unawaited(_onClose());
}
