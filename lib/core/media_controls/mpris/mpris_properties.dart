import 'package:dbus/dbus.dart';

import '../../player/play_queue.dart';
import '../../player/player_state.dart';
import '../../player/repeat_mode.dart';
import '../../player/track.dart';

const mprisObjectPath = '/org/mpris/MediaPlayer2';
const mprisRootInterface = 'org.mpris.MediaPlayer2';
const mprisPlayerInterface = 'org.mpris.MediaPlayer2.Player';
const mprisNoTrackPath = '/org/mpris/MediaPlayer2/TrackList/NoTrack';
const _trackPathPrefix = '/io/github/kanaru313/kanaru/track';

/// Properties that change every tick and are read on demand; clients get no
/// `PropertiesChanged` for them, only `Seeked`.
const _unsignaledProperties = {'Position'};

/// Fixed properties of `org.mpris.MediaPlayer2`.
Map<String, DBusValue> rootProperties() => {
  'CanQuit': const DBusBoolean(false),
  'Fullscreen': const DBusBoolean(false),
  'CanSetFullscreen': const DBusBoolean(false),
  'CanRaise': const DBusBoolean(true),
  'HasTrackList': const DBusBoolean(false),
  'Identity': const DBusString('Kanaru'),
  'DesktopEntry': const DBusString('io.github.kanaru313.kanaru'),
  'SupportedUriSchemes': DBusArray.string(const []),
  'SupportedMimeTypes': DBusArray.string(const []),
};

/// Hands out track ids. An id is stable while the queue stays the one that
/// was opened (shuffle, moves and removals keep `original`, adding tracks only
/// extends it, and an index into it is never reused) and changes when a new
/// queue is opened or the queue is cleared, so a client holding an old id
/// cannot seek the wrong track.
class MprisTrackIds {
  List<Track>? _original;
  int _generation = 0;

  /// Call with every queue before asking for ids.
  void observe(PlayQueue queue) {
    final original = queue.original;
    if (identical(original, _original)) return;
    final extended = _extends(original, _original);
    _original = original;
    if (!extended) _generation++;
  }

  /// Whether [tracks] is [before] plus more: tracks were added to the same
  /// queue, so the old ids still point at the same tracks. The same tracks
  /// opened again are a new queue.
  static bool _extends(List<Track> tracks, List<Track>? before) {
    if (before == null || tracks.length <= before.length) return false;
    for (var i = 0; i < before.length; i++) {
      if (!identical(tracks[i], before[i])) return false;
    }
    return true;
  }

  DBusObjectPath of(PlayQueue queue) => queue.isEmpty
      ? DBusObjectPath(mprisNoTrackPath)
      : DBusObjectPath(
          '$_trackPathPrefix/${_generation}_${queue.order[queue.index]}',
        );
}

/// `file://` URL for [uri], or `null` for anything else. Remote tracks are
/// served through a local proxy whose URL (and token) must not be published.
String? mprisFileUrl(String? uri) {
  if (uri == null || uri.isEmpty) return null;
  if (uri.startsWith('/')) return Uri.file(uri).toString();
  final parsed = Uri.tryParse(uri);
  return parsed != null && parsed.scheme == 'file' ? parsed.toString() : null;
}

String mprisPlaybackStatus(PlayerState state) {
  // Stopped wins: the engine can still report `playing` for a moment after
  // a stop.
  if (state.queue.isEmpty || state.stopped) return 'Stopped';
  return state.playing ? 'Playing' : 'Paused';
}

String mprisLoopStatus(RepeatMode mode) => switch (mode) {
  RepeatMode.off => 'None',
  RepeatMode.one => 'Track',
  RepeatMode.all => 'Playlist',
};

RepeatMode? repeatModeFromLoopStatus(String status) => switch (status) {
  'None' => RepeatMode.off,
  'Track' => RepeatMode.one,
  'Playlist' => RepeatMode.all,
  _ => null,
};

/// `a{sv}` for the current track, using the types clients insist on: object
/// path id, int64 microseconds length, string array artist.
DBusValue mprisMetadata(PlayerState state, MprisTrackIds ids) {
  final track = state.queue.current;
  if (track == null) {
    return DBusDict.stringVariant({
      'mpris:trackid': DBusObjectPath(mprisNoTrackPath),
    });
  }
  final length = state.duration > Duration.zero
      ? state.duration
      : track.duration;
  final url = mprisFileUrl(track.uri);
  final art = mprisFileUrl(track.artUri);
  return DBusDict.stringVariant({
    'mpris:trackid': ids.of(state.queue),
    'xesam:title': DBusString(track.title),
    'xesam:url': ?(url == null ? null : DBusString(url)),
    'mpris:length': ?(length == null ? null : DBusInt64(length.inMicroseconds)),
    'xesam:artist': ?(track.artist == null
        ? null
        : DBusArray.string([track.artist!])),
    'mpris:artUrl': ?(art == null ? null : DBusString(art)),
  });
}

/// All properties of `org.mpris.MediaPlayer2.Player` for [state].
/// [ids] must have observed `state.queue` already.
Map<String, DBusValue> playerProperties(PlayerState state, MprisTrackIds ids) {
  final queue = state.queue;
  return {
    'PlaybackStatus': DBusString(mprisPlaybackStatus(state)),
    'LoopStatus': DBusString(mprisLoopStatus(queue.repeat)),
    'Rate': const DBusDouble(1),
    'Shuffle': DBusBoolean(queue.shuffled),
    'Metadata': mprisMetadata(state, ids),
    'Volume': DBusDouble((state.volume / 100).clamp(0, 1).toDouble()),
    'Position': DBusInt64(state.position.inMicroseconds),
    'MinimumRate': const DBusDouble(1),
    'MaximumRate': const DBusDouble(1),
    'CanGoNext': DBusBoolean(queue.nextIndex != null),
    'CanGoPrevious': DBusBoolean(queue.previousIndex != null),
    'CanPlay': DBusBoolean(!queue.isEmpty),
    'CanPause': DBusBoolean(!queue.isEmpty),
    'CanSeek': DBusBoolean(state.duration > Duration.zero),
    'CanControl': const DBusBoolean(true),
  };
}

/// Entries of [next] that differ from [previous], without the properties
/// that are never signalled.
Map<String, DBusValue> changedProperties(
  Map<String, DBusValue> previous,
  Map<String, DBusValue> next,
) => {
  for (final entry in next.entries)
    if (!_unsignaledProperties.contains(entry.key) &&
        previous[entry.key] != entry.value)
      entry.key: entry.value,
};
