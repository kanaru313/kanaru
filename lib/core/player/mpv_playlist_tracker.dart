import 'package:logging/logging.dart';

import 'playback_error.dart';
import 'track.dart';

final _log = Logger('player');

/// Reads an mpv property by name, as `NativePlayer.getProperty` does.
typedef MpvPropertyReader = Future<String> Function(String name);

/// Bookkeeping for mpv's playlist, which holds at most the current entry and
/// the next one: which [Track] each entry is, which entries loaded, and which
/// track failed.
///
/// Entries are told apart by mpv's entry ids, so the same file queued twice,
/// or an event that arrives after the playlist changed again, cannot be
/// mistaken for a track change. Playlist state is always read from mpv itself
/// through the [MpvPropertyReader]. Not safe against concurrent callers: the
/// owner runs every change through one command chain.
class MpvPlaylistTracker {
  MpvPlaylistTracker({
    required this._read,
    required this._onAdvanced,
    required this._onFailed,
  });

  final MpvPropertyReader _read;

  /// Called when mpv moved on to [track]. [loaded] tells whether it had
  /// already reported a duration before that change was seen.
  final void Function(Track track, {required bool loaded}) _onAdvanced;
  final void Function(PlaybackError error) _onFailed;

  /// mpv entry ids that loaded, i.e. reported a duration. An entry left
  /// without loading is a track that failed.
  final _loaded = <int>{};
  String _lastError = '';

  /// The current track with its mpv entry id, and the queued next track
  /// with its id.
  Track? _current;
  int? _currentId;
  Track? _next;
  int? _nextId;

  Track? get current => _current;
  int? get currentId => _currentId;
  int? get nextId => _nextId;

  Future<int> readInt(String name) async =>
      int.tryParse(await _read(name)) ?? -1;

  Future<int?> entryId(int index) async =>
      int.tryParse(await _read('playlist/$index/id'));

  /// Keeps the message of the latest mpv error. Log lines reach Dart before
  /// or after the track change they belong to, so they only supply the text;
  /// [reportIfFailed] decides which track failed.
  void recordError(String message) => _lastError = message;

  /// Forgets what the previous `open` loaded.
  void resetForOpen() {
    _loaded.clear();
    _lastError = '';
  }

  /// Forgets every loaded entry.
  void clearLoaded() => _loaded.clear();

  /// Forgets the current and next track, e.g. before mpv empties its
  /// playlist, so the unfinished current track is not reported as failed.
  void forgetTracks() {
    _current = null;
    _currentId = null;
    _next = null;
    _nextId = null;
  }

  /// [track] with mpv entry [id] is the current one, as just opened.
  void setCurrent(Track track, int? id) {
    _current = track;
    _currentId = id;
  }

  /// [next] is being queued; its entry id follows with [setNextId].
  void queueNext(Track? next) {
    _next = next;
    _nextId = null;
  }

  void setNextId(int? id) => _nextId = id;

  /// The queued next entry never made it into mpv's playlist.
  void dropNext() => _next = null;

  /// Marks the entry mpv is playing now as loaded, after a duration event.
  ///
  /// Known limitation: a duration handled after mpv already moved to the next
  /// entry marks that entry. Dart cannot tell the order, because mpv batches
  /// property changes and delivers them in watch order, not event order.
  Future<void> markLoaded() async {
    final position = await readInt('playlist-playing-pos');
    final id = position < 0 ? null : await entryId(position);
    if (id != null) {
      _loaded.add(id);
      _lastError = '';
    }
  }

  /// Reports the current track as failed when mpv is leaving it unloaded.
  void reportIfFailed() {
    final track = _current;
    if (track == null || _loaded.contains(_currentId)) return;
    _log.warning('Playback failed: ${track.uri}: $_lastError');
    _onFailed(PlaybackError(track, _lastError));
    _lastError = '';
  }

  /// Moves on to [track], the queued next entry with mpv id [id].
  void _becomeCurrent(Track track, int id) {
    reportIfFailed();
    forgetTracks();
    _current = track;
    _currentId = id;
    _loaded.removeWhere((loaded) => loaded < id);
    _onAdvanced(track, loaded: _loaded.contains(id));
  }

  /// Makes the entry at [position] current when it is the queued next track,
  /// i.e. mpv moved on to it by itself. Returns whether it did.
  Future<bool> promoteIfNext(int position) async {
    final next = _next;
    final nextId = _nextId;
    if (next == null || nextId == null || await entryId(position) != nextId) {
      return false;
    }
    _becomeCurrent(next, nextId);
    return true;
  }

  /// Handles mpv going idle: the current track failed, and so did the queued
  /// next one if there was one. Returns whether anything was playing, i.e.
  /// whether the stop has to be announced.
  bool leaveIdle() {
    if (_currentId == null) return false;
    final next = _next;
    final nextId = _nextId;
    if (next != null && nextId != null) _becomeCurrent(next, nextId);
    reportIfFailed();
    forgetTracks();
    return true;
  }
}
