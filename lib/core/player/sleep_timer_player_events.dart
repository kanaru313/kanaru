import 'dart:async';

import 'player_service.dart';

/// The sleep timer's subscriptions to the player's [PlayerService.sleepStops]
/// and [PlayerService.trackEnds]. A player rebuild makes new streams, so
/// [follow] is called again after every queue change and subscribes anew
/// only when the streams changed.
class SleepTimerPlayerEvents {
  Stream<void>? _source;
  StreamSubscription<void>? _stops;
  StreamSubscription<void>? _trackEnds;

  void follow(
    PlayerService player, {
    required void Function() onStop,
    required void Function() onTrackEnd,
  }) {
    final source = player.sleepStops;
    // Every `.stream` read is a new object; equal ones share a controller.
    if (source == _source) return;
    cancel();
    _source = source;
    _stops = source.listen((_) => onStop());
    _trackEnds = player.trackEnds.listen((_) => onTrackEnd());
  }

  void cancel() {
    _stops?.cancel();
    _trackEnds?.cancel();
    _stops = null;
    _trackEnds = null;
    _source = null;
  }
}
