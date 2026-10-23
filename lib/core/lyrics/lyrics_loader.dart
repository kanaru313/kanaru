import 'package:logging/logging.dart';

import 'embedded_lyrics_reader.dart';
import 'lrc_parser.dart';
import 'lrc_sidecar_reader.dart';
import 'lyrics.dart';

final _log = Logger('lyrics');

/// The lyrics of the audio file at [path]: from its tags or from the `.lrc`
/// file next to it, [preferEmbedded] choosing which is tried first. The
/// other source is read only when the first gives nothing. A source that
/// fails is logged and counts as absent; `null` when neither has lyrics.
Future<Lyrics?> loadLyrics(
  String path, {
  required bool preferEmbedded,
  required EmbeddedLyricsReader embedded,
  required LrcSidecarReader sidecar,
}) async {
  final sources = preferEmbedded
      ? [LyricsSource.embedded, LyricsSource.sidecar]
      : [LyricsSource.sidecar, LyricsSource.embedded];
  for (final source in sources) {
    try {
      final lyrics = switch (source) {
        LyricsSource.embedded => _fromTags(await embedded.read(path)),
        LyricsSource.sidecar => _fromText(
          await sidecar.read(path),
          LyricsSource.sidecar,
        ),
      };
      if (lyrics != null) return lyrics;
    } catch (error, stackTrace) {
      _log.warning('Reading ${source.name} lyrics failed', error, stackTrace);
    }
  }
  return null;
}

/// Tag lyrics: the `SYLT` lines when there are any (already sorted and
/// capped), else the text, which may itself be LRC.
Lyrics? _fromTags(EmbeddedLyricsData? data) {
  if (data == null) return null;
  if (data.synced.isNotEmpty) {
    return Lyrics(
      lines: data.synced,
      synced: true,
      source: LyricsSource.embedded,
    );
  }
  return _fromText(data.text, LyricsSource.embedded);
}

Lyrics? _fromText(String? text, LyricsSource source) =>
    text == null ? null : parseLyricsText(text, source);
