import 'dart:async';

import '../settings/playback_prefs.dart';
import 'album_run_key_cache.dart';
import 'album_run_lookup.dart';
import 'audio_backend.dart';
import 'local_path_of.dart';
import 'play_queue.dart';
import 'replay_gain_options.dart';
import 'send_audio_call.dart';
import 'track.dart';

/// Keeps the engine's ReplayGain options in line with the settings and the
/// queue. One per `PlayerService` build (a new engine starts from mpv's
/// defaults, which is what this assumes at the start). No Riverpod in it:
/// whoever builds it feeds it the settings and the queue.
///
/// Nothing is sent until the options differ from what was sent before, so
/// default settings make no call at all.
///
/// In `auto` mode a track gets album gain when it sits in a run of the same
/// album, else track gain. The decision is made once per turn (a track that
/// really starts, see [setQueue]) and kept while the queue is edited.
class ReplayGainSync {
  ReplayGainSync({required this._backend, required AlbumRunKeyLookup lookup})
    : _keys = AlbumRunKeyCache(lookup);

  final AudioBackend _backend;
  final AlbumRunKeyCache _keys;
  bool _disposed = false;

  var _prefs = const PlaybackPrefs();
  var _applied = ReplayGainOptions.engineDefault;
  PlayQueue? _queue;

  /// The turn that is playing, as numbered by the player; `null` with no
  /// current track.
  int? _turn;

  /// Album decision of the current turn, kept until the turn ends.
  var _albumRun = false;

  /// Bumped by anything that makes a lookup in flight stale.
  var _generation = 0;

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
  }

  /// A new queue, and the number of the turn that plays. The player bumps
  /// [turn] where a track really starts (opened, skipped to, advanced to by
  /// the engine), not for a repeat one loop and not for queue edits: those
  /// renumber or reorder entries but leave the playing track as it is, so its
  /// level must not be decided again.
  void setQueue(PlayQueue queue, {required int turn}) {
    if (_disposed) return;
    _queue = queue;
    final id = queue.current == null ? null : turn;
    final newTurn = id != _turn;
    _turn = id;
    if (_prefs.replayGainMode != ReplayGainMode.auto) return;
    // The level of the playing track is fixed for its turn: editing the queue
    // changes the neighbours but not what is already playing.
    if (newTurn) _decide();
    _prefetch(queue);
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _keys.dispose();
  }

  void _applyReplayGain() {
    final options = replayGainOptionsFor(_prefs, albumRun: _albumRun);
    if (options == _applied) return;
    _applied = options;
    sendAudioCall(() => _backend.setReplayGain(options), 'ReplayGain');
  }

  /// Decides album or track for the current turn and applies it: at once when
  /// the keys are known, else once they are read, unless the turn moved on.
  void _decide() {
    final generation = ++_generation;
    final paths = _decisionPaths();
    if (paths.every(_keys.has)) {
      _albumRun = _computeAlbumRun();
      _applyReplayGain();
      return;
    }
    unawaited(
      _keys.ensure(paths).then((_) {
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
        : (queue.repeat.wrapsQueue ? 0 : null);
    final positions = {
      queue.previousIndex,
      queue.index,
      after,
      afterNext,
    }.nonNulls;
    unawaited(
      _keys.ensure({
        for (final position in positions)
          ?localPathOf(queue.trackAt(position).uri),
      }),
    );
  }
}
