import 'dart:async';

import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart' hide Track;

import 'audio_backend.dart';
import 'playback_error.dart';
import 'repeat_mode.dart';
import 'track.dart';

// Over the usual 200 lines on purpose: the playlist bookkeeping (entry ids,
// current/next, failure detection) only makes sense next to the command chain
// that keeps it consistent, so it stays in one file.

final _log = Logger('player');
final _mpvLog = Logger('mpv');

/// [AudioBackend] on top of a media_kit (libmpv) [Player].
///
/// mpv's playlist holds at most the current entry and the next one. Playlist
/// state is always read from mpv itself, never from media_kit's mirrored
/// `state.playlist`, which lags behind mpv. Entries are told apart by mpv's
/// entry ids, so the same file queued twice, or an event that arrives after
/// the playlist changed again, cannot be mistaken for a track change.

class MediaKitBackend implements AudioBackend {
  MediaKitBackend()
    : _player = Player(
        // Fixed, not tied to KANARU_LOG_LEVEL: below `warn` mpv is too noisy.
        configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
      ) {
    // mpv's default today, set so gapless does not depend on it. `weak` joins
    // tracks only when their audio format matches; `yes` would resample a
    // track to the format of the one before it. Through the chain, so it
    // applies before the first `open`.
    unawaited(
      _serial(() => _native.setProperty('gapless-audio', 'weak'))
          .catchError((Object error) {
            _log.warning('Could not enable gapless audio', error);
          }),
    );
    // media_kit turns on mpv's disk cache, but libmpv runs with config=no and
    // has no cache directory, so every opened file logged "Failed to create
    // file cache". Audio fits the RAM cache; remote streams will be cached by
    // the local proxy, not by mpv.
    unawaited(
      _serial(() => _native.setProperty('cache-on-disk', 'no'))
          .catchError((Object error) {
            _log.warning('Could not turn off the mpv disk cache', error);
          }),
    );
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
    // Log lines reach Dart before or after the track change they belong to,
    // so they only supply the message; [_reportIfFailed] decides which track
    // failed.
    _forwardError = _player.stream.error.listen((m) => _lastError = m);
    // No de-duplication here or in media_kit: its `distinct` compares
    // `PlayerLog` objects, which have no `==`, so every line gets through.
    _forwardLog = _player.stream.log.listen((entry) {
      final level = switch (entry.level) {
        'error' || 'fatal' => Level.SEVERE,
        _ => Level.WARNING,
      };
      _mpvLog.log(level, '${entry.prefix}: ${entry.text}');
    });
    _forwardDuration = _player.stream.duration.listen((duration) {
      _duration.add(duration);
      if (duration > Duration.zero) unawaited(_markLoaded());
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
  }

  final Player _player;
  late final StreamSubscription<bool> _forwardCompleted;
  late final StreamSubscription<String> _forwardError;
  late final StreamSubscription<PlayerLog> _forwardLog;
  late final StreamSubscription<Duration> _forwardDuration;

  /// Registration of the playlist observer, which waits for the player to
  /// initialize.
  late final Future<void> _observing;
  final _advanced = StreamController<Track>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _failed = StreamController<PlaybackError>.broadcast();
  final _duration = StreamController<Duration>.broadcast();

  /// mpv entry ids that loaded, i.e. reported a duration. An entry left
  /// without loading is a track that failed.
  final _loaded = <int>{};
  String _lastError = '';

  /// `open` calls waiting in the chain. Each one replaces the playlist, so
  /// a track change seen before it runs belongs to the old queue.
  int _opensPending = 0;

  bool _disposed = false;

  /// Tail of the command chain: every playlist change runs one at a time.
  Future<void> _pending = Future.value();

  /// The current track with its mpv entry id, and the queued next track
  /// with its id.
  Track? _current;
  int? _currentId;
  Track? _next;
  int? _nextId;

  NativePlayer get _native => _player.platform as NativePlayer;

  Future<void> _serial(Future<void> Function() command) {
    final run = _pending.then((_) => _disposed ? null : command());
    // A failed command must not block the ones after it.
    _pending = run.catchError((_) {});
    return run;
  }

  Future<int> _intProperty(String name) async =>
      int.tryParse(await _native.getProperty(name)) ?? -1;

  Future<int?> _entryId(int index) async =>
      int.tryParse(await _native.getProperty('playlist/$index/id'));

  Future<void> _queueNext(Track? next) async {
    _next = next;
    _nextId = null;
    if (next == null) return;
    await _native.command(['loadfile', next.uri, 'append']);
    final last = await _intProperty('playlist-count') - 1;
    // mpv went idle before the entry arrived, so it was never tried and
    // never will be: drop it, and the idle handler reports the stop.
    if (await _intProperty('playlist-playing-pos') < 0) {
      await _native.command(['playlist-remove', '$last']);
      _next = null;
      return;
    }
    _nextId = await _entryId(last);
  }

  Future<void> _markLoaded() async {
    if (_disposed) return;
    final position = await _intProperty('playlist-playing-pos');
    final id = position < 0 ? null : await _entryId(position);
    if (id != null) {
      _loaded.add(id);
      _lastError = '';
    }
  }

  /// Reports the current track as failed when mpv is leaving it unloaded.
  void _reportIfFailed() {
    final track = _current;
    if (track == null || _loaded.contains(_currentId)) return;
    _log.warning('Playback failed: ${track.uri}: $_lastError');
    _failed.add(PlaybackError(track, _lastError));
    _lastError = '';
  }

  /// Moves on to [track], the queued next entry with mpv id [id].
  void _becomeCurrent(Track track, int id) {
    _reportIfFailed();
    _current = track;
    _currentId = id;
    _next = null;
    _nextId = null;
    _loaded.removeWhere((loaded) => loaded < id);
    _advanced.add(track);
    // The track loaded before its change was reported, so its duration came
    // first too; listeners reset it on the change, so send it again.
    if (_loaded.contains(id)) _duration.add(_player.state.duration);
  }

  Future<void> _onPlayingPosition() async {
    if (_opensPending > 0) return;
    final position = await _intProperty('playlist-playing-pos');
    if (position < 0) {
      // Nothing playable left: the current track failed, and so did the
      // queued next one if there was one.
      if (_currentId == null) return;
      final next = _next;
      final nextId = _nextId;
      if (next != null && nextId != null) _becomeCurrent(next, nextId);
      _reportIfFailed();
      _current = null;
      _currentId = null;
      _completed.add(true);
      return;
    }
    await _promoteIfNext(position);
  }

  /// Makes the entry at [position] current when it is the queued next track,
  /// i.e. mpv moved on to it by itself. Returns whether it did.
  Future<bool> _promoteIfNext(int position) async {
    if (_nextId == null || await _entryId(position) != _nextId) return false;
    _becomeCurrent(_next!, _nextId!);
    // Drop the finished entries so the playlist is [current] again.
    for (var i = 0; i < position; i++) {
      await _native.command(['playlist-remove', '0']);
    }
    return true;
  }

  @override
  Future<void> open(Track track, {Track? next, bool play = true}) {
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
        _loaded.clear();
        _lastError = '';
        await _player.open(Media(track.uri), play: play);
        _current = track;
        _currentId = await _entryId(0);
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
    final count = await _intProperty('playlist-count');
    // Append before removing the old next entry, so mpv never reaches the
    // end of the current track with nothing queued after it.
    await _queueNext(next);
    for (var i = count - 1; i > position; i--) {
      await _native.command(['playlist-remove', '$i']);
    }
  });

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
    _current = null;
    _currentId = null;
    _next = null;
    _nextId = null;
    _loaded.clear();
    await _player.stop();
  });

  @override
  Future<void> seek(Duration position) => _serial(() => _player.seek(position));

  @override
  Future<void> setVolume(double volume) =>
      _serial(() => _player.setVolume(volume));

  @override
  Future<void> setRepeat(RepeatMode mode) => _serial(
    () => _player.setPlaylistMode(
      mode == RepeatMode.one ? PlaylistMode.single : PlaylistMode.none,
    ),
  );

  @override
  Stream<Track> get advanced => _advanced.stream;

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
    try {
      await _observing;
      await _native.unobserveProperty('playlist-playing-pos');
    } on ArgumentError {
      // Registration failed, so there is nothing to unobserve.
    }
    await _forwardCompleted.cancel();
    await _forwardError.cancel();
    await _forwardLog.cancel();
    await _forwardDuration.cancel();
    await _pending;
    await _player.dispose();
    await _advanced.close();
    await _completed.close();
    await _failed.close();
    await _duration.close();
  }
}
