import 'dart:async';

import 'package:logging/logging.dart';

final _log = Logger('exit');

/// Runs the exit [steps] together and waits for all of them, but at most
/// [cap]. Never throws: a failing step is logged and the others still run,
/// and a flush that takes too long is abandoned, because the app must close.
Future<void> flushBeforeExit(
  Iterable<Future<void> Function()> steps, {
  Duration cap = const Duration(seconds: 2),
}) async {
  final running = [
    for (final step in steps)
      Future<void>.sync(step).catchError((Object error) {
        // The type only: messages may carry file paths.
        _log.warning('Exit flush step failed (${error.runtimeType})');
      }),
  ];
  await Future.wait(running)
      .then<void>((_) {})
      .timeout(cap, onTimeout: () => _log.warning('Exit flush timed out'));
}

/// Builds the handler for a window close request.
///
/// The window manager disconnects Flutter's own close handler, so
/// `AppLifecycleListener.onExitRequested` never fires; the app prevents the
/// close and calls this handler instead. The first call hides the window (so
/// quitting looks instant), pauses (so nothing advances or starts a new
/// playthrough during the flush), flushes, then [destroy]s the window.
///
/// A close request while flushing means the user insists: [exit] at once.
/// [destroy] itself makes GTK emit another close request, which is ignored
/// once destroying has started. If [destroy] fails or takes longer than
/// [destroyTimeout], [exit] ends the process; after it succeeds the same
/// timeout is a fallback for a process that does not end on its own.
Future<void> Function() exitOnClose({
  required Future<void> Function() hide,
  required Future<void> Function() pause,
  required List<Future<void> Function()> flushSteps,
  required Future<void> Function() destroy,
  required Never Function() exit,
  Duration cap = const Duration(seconds: 2),
  Duration destroyTimeout = const Duration(seconds: 1),
}) {
  var flushing = false;
  var destroying = false;
  return () async {
    if (destroying) return;
    if (flushing) exit();
    flushing = true;
    // Not awaited: the window disappearing must not wait for the compositor.
    unawaited(
      Future<void>.sync(hide).catchError((Object error) {
        _log.warning('Could not hide the window (${error.runtimeType})');
      }),
    );
    // Its synchronous part flips the playing state, which queues the pause
    // writes of the recorder and the session saver before they are flushed.
    final paused = Future<void>.sync(pause);
    await flushBeforeExit([() => paused, ...flushSteps], cap: cap);
    destroying = true;
    try {
      await destroy().timeout(destroyTimeout);
    } catch (error) {
      _log.warning('Window destroy failed (${error.runtimeType})');
      exit();
    }
    Timer(destroyTimeout, exit);
  };
}
