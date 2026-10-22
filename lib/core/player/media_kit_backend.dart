import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart' hide Track;

import 'audio_backend.dart';
import 'audio_output_device.dart';
import 'mpv_audio_output.dart';
import 'mpv_playlist_tracker.dart';
import 'mpv_startup_options.dart';
import 'playback_error.dart';
import 'repeat_mode.dart';
import 'replay_gain_options.dart';
import 'track.dart';

final _log = Logger('player');
final _mpvLog = Logger('mpv');

/// Level for an mpv log line. `error`/`fatal` are SEVERE, the rest WARNING,
/// except the failed file open of `lavf`: media_kit's `open` stops the
/// playlist first, which aborts an open still in progress, and mpv prints the
/// same line as for a broken file. A broken file is reported by the playlist
/// tracker as a warning (and by `cplayer`/`stream` errors), so this one is
/// only debug detail.
@visibleForTesting
Level mpvLogLevel(String prefix, String level, String text) {
  if (prefix == 'lavf' && text.startsWith('avformat_open_input() failed')) {
    return Level.FINE;
  }
  return level == 'error' || level == 'fatal' ? Level.SEVERE : Level.WARNING;
}

/// [AudioBackend] on top of a media_kit (libmpv) [Player].
///
/// Owns the command chain that runs every playlist change one at a time, and
/// forwards media_kit's streams. The playlist bookkeeping lives in
/// [MpvPlaylistTracker]. Playlist state is always read from mpv itself, never
/// from media_kit's mirrored `state.playlist`, which lags behind mpv.
class MediaKitBackend implements AudioBackend {
  /// mpv's largest `loop-file` count. Repeat one sets it and sets it again
  /// after each loop, so the counter shows `_loopBudget - 1` only for the
  /// moment between a loop and its re-arm.
  static const _loopBudget = 10000;

  MediaKitBackend()
    : _player = Player(
        // Fixed, not tied to KANARU_LOG_LEVEL: below `warn` mpv is too noisy.
        configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
      ) {
    _tracker = MpvPlaylistTracker(
      read: (name) => _native.getProperty(name),
      onAdvanced: (track, {required loaded}) {
        _advanced.add(track);
        // The track loaded before its change was reported, so its duration
        // came first too; listeners reset it on the change, so send it again.
        if (loaded) _duration.add(_player.state.duration);
      },
      onFailed: _failed.add,
    );
    _audio = MpvAudioOutput(_player, _native);
    // Through the chain, so they apply before the first `open`.
    for (final (name, value) in mpvStartupOptions) {
      unawaited(
        _serial(() => _native.setProperty(name, value))
            .catchError((Object error) {
              _log.warning('Could not set the mpv option $name', error);
            }),
      );
    }
    // Through the chain, so the end of the last track is not reported after
    // the user picked another one.
    _forwardCompleted = _player.stream.completed.listen((done) {
      // Judged on arrival: an `open` queued by then replaces what ended.
      if (!done || _opensPending > 0) return;
      unawaited(
        _serial(() async {
          if (_opensPending == 0) _completed.add(true);
        }),
      );
    });
    _forwardError = _player.stream.error.listen(_tracker.recordError);
    // No de-duplication here or in media_kit: its `distinct` compares
    // `PlayerLog` objects, which have no `==`, so every line gets through.
    _forwardLog = _player.stream.log.listen((entry) {
      _audio.onMpvLog(entry);
      _mpvLog.log(
        mpvLogLevel(entry.prefix, entry.level, entry.text),
        '${entry.prefix}: ${entry.text}',
      );
    });
    _forwardDuration = _player.stream.duration.listen((duration) {
      _duration.add(duration);
      if (duration > Duration.zero && !_disposed) {
        unawaited(_tracker.markLoaded());
      }
    });
    // The value is ignored: the handler reads the position again once it
    // runs, after any command queued before it.
    _observing = _native
        .observeProperty('playlist-playing-pos', (_) async {
          unawaited(_serial(_onPlayingPosition));
        })
        .catchError((Object error) {
          // Without it no track change or failure is ever reported.
          _log.warning('Could not observe the mpv playlist', error);
        });
    // Each loop of the file counts `loop-file` down. Same pattern as above.
    _observingLoops = _native
        .observeProperty('remaining-file-loops', (_) async {
          // Judged on arrival: an `open` queued by now replaces the file
          // that looped.
          if (_opensPending > 0) return;
          unawaited(_serial(_onLoopCounter));
        })
        .catchError((Object error) {
          // Repeat one still loops; only the count of plays is lost.
          _log.warning('Could not observe repeat one loops', error);
        });
  }

  final Player _player;
  late final MpvAudioOutput _audio;
  late final MpvPlaylistTracker _tracker;
  late final StreamSubscription<bool> _forwardCompleted;
  late final StreamSubscription<String> _forwardError;
  late final StreamSubscription<PlayerLog> _forwardLog;
  late final StreamSubscription<Duration> _forwardDuration;

  /// Registration of the playlist observer, which waits for the player to
  /// initialize.
  late final Future<void> _observing;

  /// Same for the repeat one loop counter.
  late final Future<void> _observingLoops;
  final _advanced = StreamController<Track>.broadcast();
  final _looped = StreamController<Track>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _failed = StreamController<PlaybackError>.broadcast();
  final _duration = StreamController<Duration>.broadcast();

  /// `open` calls waiting in the chain. Each one replaces the playlist, so
  /// a track change seen before it runs belongs to the old queue.
  int _opensPending = 0;

  bool _disposed = false;

  /// Tail of the command chain: every playlist change runs one at a time.
  Future<void> _pending = Future.value();

  NativePlayer get _native => _player.platform as NativePlayer;

  Future<void> _serial(Future<void> Function() command) {
    final run = _pending.then((_) => _disposed ? null : command());
    // A failed command must not block the ones after it.
    _pending = run.catchError((_) {});
    return run;
  }

  Future<int> _intProperty(String name) => _tracker.readInt(name);

  Future<void> _queueNext(Track? next) async {
    _tracker.queueNext(next);
    if (next == null) return;
    await _native.command(['loadfile', next.uri, 'append']);
    final last = await _intProperty('playlist-count') - 1;
    // mpv went idle before the entry arrived, so it was never tried and
    // never will be: drop it, and the idle handler reports the stop.
    if (await _intProperty('playlist-playing-pos') < 0) {
      await _native.command(['playlist-remove', '$last']);
      _tracker.dropNext();
      return;
    }
    _tracker.setNextId(await _tracker.entryId(last));
  }

  Future<void> _onPlayingPosition() async {
    if (_opensPending > 0) return;
    final position = await _intProperty('playlist-playing-pos');
    if (position < 0) {
      if (_tracker.leaveIdle()) _completed.add(true);
      return;
    }
    await _promoteIfNext(position);
  }

  /// The loop counter changed. A value between zero and the budget is a loop
  /// of the current file: report it and arm the full budget again. The
  /// budget itself (file load, re-arm), zero (repeat off) and -1 are not.
  Future<void> _onLoopCounter() async {
    if (_opensPending > 0) return;
    final remaining = int.tryParse(
      await _native.getProperty('remaining-file-loops'),
    );
    // An `open` was queued during the read: the counter is the old track's.
    if (_opensPending > 0) return;
    final track = _tracker.current;
    if (remaining == null ||
        remaining <= 0 ||
        remaining >= _loopBudget ||
        track == null) {
      return;
    }
    _looped.add(track);
    await _native.setProperty('loop-file', '$_loopBudget');
  }

  /// Makes the entry at [position] current when it is the queued next track,
  /// i.e. mpv moved on to it by itself. Returns whether it did.
  Future<bool> _promoteIfNext(int position) async {
    if (!await _tracker.promoteIfNext(position)) return false;
    // Drop the finished entries so the playlist is [current] again.
    for (var i = 0; i < position; i++) {
      await _removeUnlessPlaying(0);
    }
    return true;
  }

  @override
  Future<void> open(
    Track track, {
    Track? next,
    bool play = true,
    Duration start = Duration.zero,
  }) {
    _opensPending++;
    return _serial(() async {
      // A newer `open` is queued behind this one and would replace it, so
      // running it only delays that one. Skipped before anything changes, so
      // the bookkeeping stays what the last `open` that ran left.
      if (_opensPending > 1) {
        _opensPending--;
        return;
      }
      try {
        _tracker.resetForOpen();
        // media_kit applies `start` while this entry loads and clears it
        // when it unloads, so the next entry, appended with a raw
        // `loadfile`, still starts at zero. Its list of opened media is
        // indexed by playlist position, which drifts once finished entries
        // are removed; harmless, as nothing reloads an entry but `open`,
        // which resets that list.
        await _player.open(
          Media(track.uri, start: start > Duration.zero ? start : null),
          play: play,
        );
        _tracker.setCurrent(track, await _tracker.entryId(0));
        await _queueNext(next);
      } finally {
        _opensPending--;
      }
    });
  }

  @override
  Future<void> setNext(Track? next) => _serial(() async {
    // A pending `open` queues its own next track.
    if (_opensPending > 0) return;
    final position = await _intProperty('playlist-playing-pos');
    // mpv is idle: the handler still has to report what failed, and `open`
    // starts it again.
    if (position < 0) return;
    // mpv already moved on to the old next track and its handler has not run
    // yet. Announce that change instead: [next] was picked to follow the
    // track before, and the listener picks a new one for the track now
    // playing.
    if (await _promoteIfNext(position)) return;
    await _replaceNextEntry(next, position);
  });

  /// Queues [next] behind the entry at [position], which is playing, and
  /// removes the old next entry.
  Future<void> _replaceNextEntry(Track? next, int position) async {
    final count = await _intProperty('playlist-count');
    // Append before removing the old next entry, so mpv never reaches the
    // end of the current track with nothing queued after it.
    final old = (track: _tracker.next, id: _tracker.nextId);
    await _queueNext(next);
    final appended = (track: _tracker.next, id: _tracker.nextId);
    // mpv may have started the old next entry while [next] was appended.
    // That entry is playing now and stays; only the ones behind it go.
    final now = await _intProperty('playlist-playing-pos');
    var keep = position;
    var finished = 0;
    if (now > position) {
      keep = now;
      final oldTrack = old.track;
      final oldId = old.id;
      if (oldTrack != null &&
          oldId != null &&
          await _tracker.entryId(now) == oldId) {
        // The appended entry sits right behind it and is its next track.
        _tracker.promoteEntry(
          oldTrack,
          oldId,
          next: appended.track,
          nextId: appended.id,
        );
        finished = now;
      }
    }
    for (var i = count - 1; i > keep; i--) {
      await _removeUnlessPlaying(i);
    }
    // Drop the finished entries so the playlist is [current] again.
    for (var i = 0; i < finished; i++) {
      await _removeUnlessPlaying(0);
    }
  }

  /// Removes the entry at [index] unless mpv is playing it by now. The
  /// position is read again for each removal; mpv can still move on between
  /// that read and the removal, which a command cannot close.
  Future<void> _removeUnlessPlaying(int index) async {
    if (await _intProperty('playlist-playing-pos') == index) return;
    await _native.command(['playlist-remove', '$index']);
  }

  // Transport commands go through the chain too, so one sent after an `open`
  // acts on the track that `open` starts, not the one it replaces.
  @override
  Future<void> play() => _serial(_player.play);

  @override
  Future<void> pause() => _serial(_player.pause);

  @override
  Future<void> stop() => _serial(() async {
    // Forget the tracks first: stopping empties mpv's playlist, and the
    // handler would otherwise report the unfinished current track as failed.
    _tracker.forgetTracks();
    _tracker.clearLoaded();
    await _player.stop();
  });

  @override
  Future<void> seek(Duration position) => _serial(() => _player.seek(position));

  @override
  Future<void> setVolume(double volume) =>
      _serial(() => _player.setVolume(volume));

  @override
  Future<void> setRepeat(RepeatMode mode) => _serial(
    // A finite count, not `yes`: mpv counts it down and reports each loop.
    () => _native.setProperty(
      'loop-file',
      mode == RepeatMode.one ? '$_loopBudget' : 'no',
    ),
  );

  // ReplayGain and the output device run in `MpvAudioOutput`'s own chain.
  @override
  Future<void> setReplayGain(ReplayGainOptions options) =>
      _audio.setReplayGain(options);

  @override
  Future<void> setAudioDevice(String name) => _audio.setAudioDevice(name);

  @override
  List<AudioOutputDevice> get audioDevices => _audio.devices;

  @override
  Stream<List<AudioOutputDevice>> get audioDevicesChanged =>
      _audio.devicesChanged;

  @override
  Stream<String> get audioDeviceFailed => _audio.deviceFailed;

  @override
  Stream<Track> get advanced => _advanced.stream;

  @override
  Stream<Track> get looped => _looped.stream;

  @override
  Stream<bool> get playing => _player.stream.playing;

  @override
  Stream<bool> get completed => _completed.stream;

  @override
  Stream<Duration> get position => _player.stream.position;

  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Stream<PlaybackError> get failed => _failed.stream;

  @override
  Future<void> dispose() async {
    // Stop reacting to mpv first: disposing the player empties its playlist,
    // which would otherwise reach the handler after the streams are closed.
    _disposed = true;
    final audioDone = _audio.dispose();
    try {
      await _observing;
      await _native.unobserveProperty('playlist-playing-pos');
    } on ArgumentError {
      // Registration failed, so there is nothing to unobserve.
    }
    try {
      await _observingLoops;
      await _native.unobserveProperty('remaining-file-loops');
    } on ArgumentError {
      // Same.
    }
    await _forwardCompleted.cancel();
    await _forwardError.cancel();
    await _forwardLog.cancel();
    await _forwardDuration.cancel();
    await _pending;
    await audioDone;
    await _player.dispose();
    await _advanced.close();
    await _looped.close();
    await _completed.close();
    await _failed.close();
    await _duration.close();
  }
}
