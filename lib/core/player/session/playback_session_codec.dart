import 'package:logging/logging.dart';

import '../../indexer/audio_file_types.dart' show isAudioFile;
import '../../indexer/cover_paths.dart' show coverPath;
import '../cover_path_in_directory.dart';
import '../repeat_mode.dart';
import '../track.dart';
import 'playback_session.dart';

final _log = Logger('player');

/// Version written by this build. A file with a higher one came from a newer
/// Kanaru and is left alone.
const playbackSessionVersion = 1;

/// JSON for [session].
///
/// Tracks are stored by the URI handed to the player. That must stay a
/// stable source URI: a remote track must be stored by its source, never by
/// the local proxy URL it plays through, which carries a token and dies with
/// the process.
///
/// A thumbnail inside [coverDirectory] is stored as its `coverKey` (the path
/// below that folder), so the file survives a moved cache and stays small;
/// any other art keeps its `artUri`. `coverKey` is an optional per-track key
/// that older readers ignore, so the version stays the same.
Map<String, Object?> encodePlaybackSession(
  PlaybackSession session, {
  String? coverDirectory,
}) => {
  'version': playbackSessionVersion,
  'tracks': [
    for (final track in session.tracks) _encodeTrack(track, coverDirectory),
  ],
  'order': session.order,
  'unshuffledOrder': session.unshuffledOrder,
  'index': session.index,
  'shuffled': session.shuffled,
  'repeat': session.repeat.name,
  'positionMs': session.position.inMilliseconds,
  'volume': session.volume,
  'volumeBeforeMute': session.volumeBeforeMute,
};

/// The `version` of a decoded file, or `null` when it has none that makes
/// sense.
int? playbackSessionVersionOf(Map<String, Object?> json) {
  final version = json['version'];
  return version is int && version >= 1 ? version : null;
}

/// Reads a session written by [encodePlaybackSession]. Throws a
/// [FormatException] when anything is off: a queue that points past its
/// tracks would break the player, so a half-valid session is not restored.
/// Unknown keys are ignored.
///
/// A track whose URI is not a plain absolute path to an audio file is
/// dropped from the queue instead (see [_isRestorableUri]); the rest of the
/// session is restored. A `coverKey` is resolved against
/// [coverDirectory]; without a folder, or when the key is malformed, the
/// track has no art.
PlaybackSession decodePlaybackSession(
  Map<String, Object?> json, {
  String? coverDirectory,
}) {
  final rawTracks = json['tracks'];
  if (rawTracks is! List) throw const FormatException('tracks');
  final tracks = [
    for (final raw in rawTracks) _decodeTrack(raw, coverDirectory),
  ];

  final order = _intList(json['order'], 'order');
  if (order == null) throw const FormatException('order');
  final seen = <int>{};
  for (final entry in order) {
    if (entry < 0 || entry >= tracks.length || !seen.add(entry)) {
      throw const FormatException('order');
    }
  }

  final unshuffledOrder = _intList(json['unshuffledOrder'], 'unshuffledOrder');
  if (unshuffledOrder != null &&
      (unshuffledOrder.length != order.length ||
          !seen.containsAll(unshuffledOrder) ||
          unshuffledOrder.toSet().length != order.length)) {
    throw const FormatException('unshuffledOrder');
  }

  final index = json['index'];
  if (index is! int ||
      (order.isNotEmpty && (index < 0 || index >= order.length))) {
    throw const FormatException('index');
  }

  final shuffled = json['shuffled'];
  if (shuffled is! bool) throw const FormatException('shuffled');

  final repeat = RepeatMode.values
      .where((mode) => mode.name == json['repeat'])
      .firstOrNull;
  if (repeat == null) throw const FormatException('repeat');

  final position = json['positionMs'];
  if (position is! int || position < 0) {
    throw const FormatException('positionMs');
  }

  final volume = _volume(json['volume']);
  if (volume == null) throw const FormatException('volume');
  final rawBeforeMute = json['volumeBeforeMute'];
  final volumeBeforeMute = rawBeforeMute == null
      ? null
      : _volume(rawBeforeMute);
  if (rawBeforeMute != null && volumeBeforeMute == null) {
    throw const FormatException('volumeBeforeMute');
  }

  final session = PlaybackSession(
    tracks: tracks,
    order: order,
    unshuffledOrder: unshuffledOrder,
    index: order.isEmpty ? 0 : index,
    shuffled: shuffled,
    repeat: repeat,
    position: Duration(milliseconds: position),
    volume: volume,
    volumeBeforeMute: volumeBeforeMute,
  );
  return _withoutUnrestorable(session);
}

/// Whether [uri] is safe to hand to the engine as a file: an absolute path
/// (mpv opens a string that starts with `/` as a file, never as a URL or an
/// `edl://`, `av://` or `file://` source) with no NUL, ending in an audio
/// extension. The file is not looked for: a library on a drive that is not
/// mounted yet keeps its queue.
bool _isRestorableUri(String uri) =>
    uri.startsWith('/') && !uri.contains('\u0000') && isAudioFile(uri);

/// [session] without the tracks that fail [_isRestorableUri]. Order and
/// unshuffled order are renumbered to the tracks that are left. The current
/// track stays current; when it was dropped, the one that took its place in
/// the order is (the last one at the end), at the start of the track.
PlaybackSession _withoutUnrestorable(PlaybackSession session) {
  final tracks = session.tracks;
  final renumbered = List<int>.filled(tracks.length, -1);
  final kept = <Track>[];
  for (var i = 0; i < tracks.length; i++) {
    if (_isRestorableUri(tracks[i].uri)) {
      renumbered[i] = kept.length;
      kept.add(tracks[i]);
    }
  }
  if (kept.length == tracks.length) return session;
  // The count only: a path is private and can be long.
  _log.warning(
    'Dropped ${tracks.length - kept.length} queued tracks that are not '
    'local audio files',
  );

  List<int> renumber(List<int> entries) => [
    for (final entry in entries)
      if (renumbered[entry] >= 0) renumbered[entry],
  ];
  final order = renumber(session.order);
  var index = 0;
  var position = session.position;
  if (session.order.isNotEmpty) {
    final current = renumbered[session.order[session.index]];
    if (current >= 0) {
      index = order.indexOf(current);
    } else {
      // Entries before the current one that survived; the first one after
      // it moves into that slot.
      index = renumber(session.order.sublist(0, session.index)).length;
      position = Duration.zero;
    }
  }
  final unshuffled = session.unshuffledOrder;
  return PlaybackSession(
    tracks: kept,
    order: order,
    unshuffledOrder: unshuffled == null ? null : renumber(unshuffled),
    index: order.isEmpty ? 0 : index.clamp(0, order.length - 1),
    shuffled: session.shuffled,
    repeat: session.repeat,
    position: position,
    volume: session.volume,
    volumeBeforeMute: session.volumeBeforeMute,
  );
}

Map<String, Object?> _encodeTrack(Track track, String? coverDirectory) {
  final art = track.artUri;
  final isThumbnail =
      coverDirectory != null && isCoverPathIn(coverDirectory, art);
  return {
    'uri': track.uri,
    'title': track.title,
    'artist': track.artist,
    if (isThumbnail)
      'coverKey': art!.substring(coverDirectory.length + 1)
    else
      'artUri': art,
    'durationMs': track.duration?.inMilliseconds,
  };
}

Track _decodeTrack(Object? raw, String? coverDirectory) {
  if (raw is! Map) throw const FormatException('track');
  final uri = raw['uri'];
  final title = raw['title'];
  final artist = raw['artist'];
  final artUri = raw['artUri'];
  final coverKey = raw['coverKey'];
  final duration = raw['durationMs'];
  if (uri is! String || uri.isEmpty || title is! String) {
    throw const FormatException('track');
  }
  if ((artist != null && artist is! String) ||
      (artUri != null && artUri is! String) ||
      (coverKey != null && coverKey is! String) ||
      (duration != null && (duration is! int || duration < 0))) {
    throw const FormatException('track');
  }
  return Track(
    uri: uri,
    title: title,
    artist: artist as String?,
    artUri: coverKey is String
        ? coverPath(coverDirectory, coverKey)
        : artUri as String?,
    duration: duration == null ? null : Duration(milliseconds: duration as int),
  );
}

/// `null` for a missing value; throws for anything but a list of ints.
List<int>? _intList(Object? raw, String key) {
  if (raw == null) return null;
  if (raw is! List || raw.any((e) => e is! int)) throw FormatException(key);
  return List<int>.unmodifiable(raw.cast<int>());
}

/// A finite number, clamped to 0–100; `null` for anything else.
double? _volume(Object? raw) {
  if (raw is! num || !raw.isFinite) return null;
  return raw.clamp(0, 100).toDouble();
}
