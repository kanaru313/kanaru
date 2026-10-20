import '../repeat_mode.dart';
import '../track.dart';
import 'playback_session.dart';

/// Version written by this build. A file with a higher one came from a newer
/// Kanaru and is left alone.
const playbackSessionVersion = 1;

/// JSON for [session].
///
/// Tracks are stored by the URI handed to the player. That must stay a
/// stable source URI: a remote track must be stored by its source, never by
/// the local proxy URL it plays through, which carries a token and dies with
/// the process.
Map<String, Object?> encodePlaybackSession(PlaybackSession session) => {
  'version': playbackSessionVersion,
  'tracks': [for (final track in session.tracks) _encodeTrack(track)],
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
PlaybackSession decodePlaybackSession(Map<String, Object?> json) {
  final rawTracks = json['tracks'];
  if (rawTracks is! List) throw const FormatException('tracks');
  final tracks = [for (final raw in rawTracks) _decodeTrack(raw)];

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

  return PlaybackSession(
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
}

Map<String, Object?> _encodeTrack(Track track) => {
  'uri': track.uri,
  'title': track.title,
  'artist': track.artist,
  'artUri': track.artUri,
  'durationMs': track.duration?.inMilliseconds,
};

Track _decodeTrack(Object? raw) {
  if (raw is! Map) throw const FormatException('track');
  final uri = raw['uri'];
  final title = raw['title'];
  final artist = raw['artist'];
  final artUri = raw['artUri'];
  final duration = raw['durationMs'];
  if (uri is! String || uri.isEmpty || title is! String) {
    throw const FormatException('track');
  }
  if ((artist != null && artist is! String) ||
      (artUri != null && artUri is! String) ||
      (duration != null && (duration is! int || duration < 0))) {
    throw const FormatException('track');
  }
  return Track(
    uri: uri,
    title: title,
    artist: artist as String?,
    artUri: artUri as String?,
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
