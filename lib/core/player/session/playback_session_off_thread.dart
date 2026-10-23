import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../track.dart';
import 'playback_session_codec.dart';

/// The parts of `playback-session.json` that grow with the queue, as JSON
/// text. `null` for a part the caller did not hand over to be encoded.
typedef PlaybackSessionHeavyJson = ({
  String? tracks,
  String? order,
  String? unshuffledOrder,
});

/// Writes the session file at [path] on another isolate, so neither the
/// encoding nor the I/O of a long queue blocks the UI.
///
/// [light] is the JSON object of the small fields (see
/// `encodePlaybackSessionLight`). Each heavy part comes either as text the
/// caller kept from an earlier write (`*Json`) or as the value to encode now
/// (`tracks`, `order`, `unshuffledOrder`); [encodeUnshuffled] says whether
/// [unshuffledOrder] is to be encoded (it may be `null`, which is written as
/// `null`). The file goes to `<path>.<pid>.tmp` first and is renamed over
/// [path]. Returns the parts that were encoded, for the caller to keep.
/// Throws what the write threw; the temporary file is then left for the
/// caller to delete.
Future<PlaybackSessionHeavyJson> writePlaybackSessionOffThread({
  required String path,
  required Map<String, Object?> light,
  String? tracksJson,
  List<Track>? tracks,
  String? coverDirectory,
  String? orderJson,
  List<int>? order,
  String? unshuffledJson,
  bool encodeUnshuffled = false,
  List<int>? unshuffledOrder,
}) {
  assert((tracksJson == null) != (tracks == null));
  assert((orderJson == null) != (order == null));
  assert((unshuffledJson == null) == encodeUnshuffled);
  return Isolate.run(() async {
    final encodedTracks = tracks == null
        ? null
        : jsonEncode(encodePlaybackSessionTracks(tracks, coverDirectory));
    final encodedOrder = order == null ? null : jsonEncode(order);
    final encodedUnshuffled = encodeUnshuffled
        ? jsonEncode(unshuffledOrder)
        : null;
    final text = composePlaybackSessionJson(
      light: light,
      tracksJson: encodedTracks ?? tracksJson!,
      orderJson: encodedOrder ?? orderJson!,
      unshuffledJson: encodedUnshuffled ?? unshuffledJson!,
    );
    await File(path).parent.create(recursive: true);
    final temporary = File(playbackSessionTemporaryPath(path));
    await temporary.writeAsString(text, flush: true);
    await temporary.rename(path);
    return (
      tracks: encodedTracks,
      order: encodedOrder,
      unshuffledOrder: encodedUnshuffled,
    );
  }, debugName: 'playback-session-write');
}

/// Where a write of [path] puts its bytes before renaming them over it.
String playbackSessionTemporaryPath(String path) => '$path.$pid.tmp';
