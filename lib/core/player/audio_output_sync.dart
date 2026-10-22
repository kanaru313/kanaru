import 'dart:async';

import 'package:logging/logging.dart';

import '../settings/playback_prefs.dart';
import 'album_run_lookup.dart';
import 'audio_backend.dart';
import 'audio_device_choice.dart';
import 'audio_output_device.dart';
import 'local_path_of.dart';
import 'play_queue.dart';
import 'repeat_mode.dart';
import 'replay_gain_options.dart';
import 'track.dart';

final _log = Logger('player');

/// Keeps the engine's ReplayGain options and output device in line with the
/// settings, the devices mpv lists and the queue. One per `PlayerService`
/// build (a new engine starts from mpv's defaults, which is what this assumes
/// at the start). Has no Riverpod in it: whoever builds it feeds it the
/// settings, the queue and the engine's events.
///
/// Nothing is sent to the engine until a value differs from what was sent
/// before, so default settings make no call at all.
class AudioOutputSync {
  AudioOutputSync({
    required this._backend,
    required this._lookup,
    required this._onFailedDeviceChanged,
    this.deviceSettle = const Duration(seconds: 2),
  });

  /// How long a saved device that came back must stay in the list before the
  /// output moves to it. Each move reopens the output and seeks, and a
  /// Bluetooth sink flickers while it changes profile.
  final Duration deviceSettle;

  /// Most keys kept; the oldest go first.
  static const _cacheSize = 256;

  final AudioBackend _backend;
  final AlbumRunKeyLookup _lookup;
  final void Function(String? name) _onFailedDeviceChanged;
  bool _disposed = false;

  // ReplayGain
  var _prefs = const PlaybackPrefs();
  var _applied = ReplayGainOptions.engineDefault;
  PlayQueue? _queue;

  /// The turn that is playing: queue entry and uri of the current track.
  ({int entry, String uri})? _turn;

  /// Album decision of the current turn, kept until the turn ends.
  var _albumRun = false;

  /// Bumped by anything that makes a lookup in flight stale.
  var _generation = 0;
  final _keys = <String, AlbumRunKey>{};
  final _fetching = <String>{};
  String? _lastLookupError;

  // Output device
  var _devices = const <AudioOutputDevice>[];
  var _appliedDevice = autoAudioDevice;
  String? _failed;
  bool _hadDevice = false;
  bool _needsSettle = false;
  Timer? _settleTimer;

  /// The saved device that failed to open this session, or `null`.
  String? get failedDevice => _failed;

  void setPrefs(PlaybackPrefs prefs) {
    if (_disposed) return;
    final old = _prefs;
    _prefs = prefs;
    if (prefs.replayGainMode == ReplayGainMode.auto &&
        old.replayGainMode != ReplayGainMode.auto) {
      // The setting is a user action, so the playing track may change level.
      _decide();
      final queue = _queue;
      if (queue != null) _prefetch(queue);
    } else {
      _applyReplayGain();
    }
    if (prefs.audioDeviceName != old.audioDeviceName) {
      // A different choice starts clean: no failure, no flicker wait.
      _settleTimer?.cancel();
      _hadDevice = false;
      _needsSettle = false;
      _setFailed(null);
    }
    _applyDevice();
  }

  void setDevices(List<AudioOutputDevice> devices) {
    if (_disposed) return;
    _devices = devices;
    _applyDevice();
  }

  /// The engine could not open [name] and already went back to `auto`.
  void markDeviceFailed(String name) {
    if (_disposed || name != _prefs.audioDeviceName) return;
    _appliedDevice = autoAudioDevice;
    _setFailed(name);
  }

  /// The failure mark was cleared from outside (the user picked the failed
  /// device again): use the saved device again if it is listed.
  void retryDevice() {
    if (_disposed || _failed == null) return;
    _setFailed(null);
    _applyDevice();
  }

  /// A new queue: follow the track that plays, and read the album keys of
  /// the tracks around it ahead of their turn.
  void setQueue(PlayQueue queue) {
    if (_disposed) return;
    _queue = queue;
    final current = queue.current;
    final turn = current == null
        ? null
        : (entry: queue.order[queue.index], uri: current.uri);
    final newTurn = turn != _turn;
    _turn = turn;
    if (_prefs.replayGainMode != ReplayGainMode.auto) return;
    // The level of the playing track is fixed for its turn: editing the queue
    // changes the neighbours but not what is already playing.
    if (newTurn) _decide();
    _prefetch(queue);
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _settleTimer?.cancel();
  }

  // ReplayGain

  void _applyReplayGain() {
    final options = replayGainOptionsFor(_prefs, albumRun: _albumRun);
    if (options == _applied) return;
    _applied = options;
    _send(() => _backend.setReplayGain(options), 'ReplayGain');
  }

  void _send(Future<void> Function() call, String what) {
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

  /// Decides album or track for the current turn and applies it: at once when
  /// the keys are known, else once they are read, unless the turn moved on.
  void _decide() {
    final generation = ++_generation;
    final paths = _decisionPaths();
    final missing = [
      for (final path in paths)
        if (!_keys.containsKey(path)) path,
    ];
    if (missing.isEmpty) {
      _albumRun = _computeAlbumRun();
      _applyReplayGain();
      return;
    }
    unawaited(
      _fill(missing).then((_) {
        if (_disposed || generation != _generation) return;
        _albumRun = _computeAlbumRun();
        _applyReplayGain();
      }),
    );
  }

  /// Local paths whose album key the current turn needs: the playing track
  /// and its neighbours. A track with no key cannot start a run, so when the
  /// playing track is not a local file nothing is needed.
  List<String> _decisionPaths() {
    final queue = _queue;
    final current = queue?.current;
    if (queue == null || current == null) return const [];
    final currentPath = localPathOf(current.uri);
    if (currentPath == null) return const [];
    final around = _around(queue);
    return [
      for (final track in [current, around.previous, around.next].nonNulls)
        ?localPathOf(track.uri),
    ];
  }

  /// The tracks before and after the current one in play order (wrapping on
  /// repeat all). One that is the current track itself is left out: a one
  /// track queue on repeat all, or a file queued twice in a row.
  ({Track? previous, Track? next}) _around(PlayQueue queue) {
    final current = queue.current!;
    Track? at(int? position) {
      if (position == null || position == queue.index) return null;
      final track = queue.trackAt(position);
      return track.uri == current.uri ? null : track;
    }

    return (previous: at(queue.previousIndex), next: at(queue.nextIndex));
  }

  bool _computeAlbumRun() {
    final queue = _queue;
    final current = queue?.current;
    if (queue == null || current == null) return false;
    AlbumRunKey? keyOf(Track? track) {
      final path = track == null ? null : localPathOf(track.uri);
      return path == null ? null : _keys[path];
    }

    final around = _around(queue);
    return isAlbumRun(
      previous: keyOf(around.previous),
      current: keyOf(current),
      next: keyOf(around.next),
    );
  }

  /// Reads ahead the keys of previous, current, next and the one after next.
  void _prefetch(PlayQueue queue) {
    if (queue.isEmpty) return;
    final after = queue.nextIndex;
    final afterNext = after == null
        ? null
        : after < queue.order.length - 1
        ? after + 1
        : (queue.repeat == RepeatMode.all ? 0 : null);
    final positions = {
      queue.previousIndex,
      queue.index,
      after,
      afterNext,
    }.nonNulls;
    final wanted = <String>{
      for (final position in positions)
        ?localPathOf(queue.trackAt(position).uri),
    };
    final missing = [
      for (final path in wanted)
        if (!_keys.containsKey(path) && !_fetching.contains(path)) path,
    ];
    if (missing.isNotEmpty) unawaited(_fill(missing));
  }

  /// Reads the keys of [paths] into the cache. A failure is logged once per
  /// message and leaves the paths without a key, which means no album.
  Future<void> _fill(List<String> paths) async {
    _fetching.addAll(paths);
    try {
      final found = await _lookup(paths);
      if (_disposed) return;
      for (final entry in found.entries) {
        _keys.remove(entry.key);
        _keys[entry.key] = entry.value;
      }
      while (_keys.length > _cacheSize) {
        _keys.remove(_keys.keys.first);
      }
      _lastLookupError = null;
    } on Object catch (error, stack) {
      final message = '$error';
      if (message != _lastLookupError) {
        _log.warning('Looking up album keys failed', error, stack);
      }
      _lastLookupError = message;
    } finally {
      _fetching.removeAll(paths);
    }
  }

  // Output device

  void _setFailed(String? name) {
    if (_failed == name) return;
    _failed = name;
    _onFailedDeviceChanged(name);
  }

  void _applyDevice() {
    final saved = _prefs.audioDeviceName;
    final present = isAudioDeviceAvailable(saved, _devices);
    if (!present) {
      _settleTimer?.cancel();
      _settleTimer = null;
      // Coming back after it was here is a return, not a first sighting.
      if (_hadDevice) _needsSettle = true;
      // A device that left the list is tried again when it returns.
      _setFailed(null);
      _setDevice(autoAudioDevice);
      return;
    }
    _hadDevice = true;
    if (_failed == saved) {
      _setDevice(autoAudioDevice);
      return;
    }
    if (_needsSettle) {
      _settleTimer ??= Timer(deviceSettle, () {
        _settleTimer = null;
        if (_disposed) return;
        _needsSettle = false;
        _applyDevice();
      });
      return;
    }
    _setDevice(saved!);
  }

  void _setDevice(String name) {
    if (name == _appliedDevice) return;
    _appliedDevice = name;
    _send(() => _backend.setAudioDevice(name), 'the output device');
  }
}
