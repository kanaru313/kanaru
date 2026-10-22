import 'dart:async';

import 'package:logging/logging.dart';

final _log = Logger('player');

/// Runs an engine call without waiting for it. A failure, thrown at once or
/// later, is logged: a missing ReplayGain or device change must not break
/// playback, and the next change simply tries again.
void sendAudioCall(Future<void> Function() call, String what) {
  try {
    unawaited(
      call().catchError((Object error) {
        _log.warning('Could not apply $what', error);
      }),
    );
  } on Object catch (error) {
    _log.warning('Could not apply $what', error);
  }
}
