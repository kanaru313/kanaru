import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../settings/settings_provider.dart';
import 'embedded_lyrics_reader.dart';
import 'lrc_format.dart';
import 'lyrics.dart';
import 'lyrics_loader.dart';
import 'online/lrc_sidecar_writer.dart';
import 'online/lyrics_provider.dart';
import 'online/lyrics_target.dart';
import 'online/online_lyrics_save_action.dart';
import 'playing_local_lyrics_provider.dart';

final _log = Logger('lyrics');

/// Saves the lyrics in the song's tags as its `.lrc` file.
///
/// The tags are read again and turned into lyrics the way the lyrics view
/// does (synced `SYLT` lines win over the text), so the file holds what is on
/// screen: synced lyrics as `[mm:ss.fff]` lines, plain ones as they are. With
/// [replace] an existing file goes to the trash first; without it an existing
/// file is left alone. Tags without lyrics answer `result: null`. File errors
/// come back as results, never as exceptions. No pick or choice changes;
/// [LyricsSaveOutcome.kept] is `tagPreferred` after a save while "prefer
/// embedded lyrics" is on, since the tags keep showing.
Future<LyricsSaveOutcome> saveLocalLyricsAsLrc(
  Ref ref,
  LyricsTarget target, {
  bool replace = false,
}) async {
  final path = target.path;
  if (path == null) return (result: LrcWriteResult.outsideLibrary, kept: null);
  final Lyrics? lyrics;
  try {
    lyrics = lyricsFromTags(
      await ref.read(embeddedLyricsReaderProvider).read(path),
    );
  } catch (error, stackTrace) {
    _log.warning('Reading embedded lyrics failed', error, stackTrace);
    return (result: LrcWriteResult.failed, kept: null);
  }
  if (lyrics == null) return (result: null, kept: null);
  final body = lyrics.synced
      ? LyricsBody(syncedLrc: formatLrcLines(lyrics.lines))
      : LyricsBody(plain: lyrics.lines.map((l) => l.text).join('\n'));
  final result = await ref
      .read(lrcSidecarWriterProvider)
      .write(path, body, replace: replace);
  if (!ref.mounted) return (result: result, kept: null);
  final saved =
      result == LrcWriteResult.written || result == LrcWriteResult.identical;
  // After a trashed old file the song's own lyrics must be read again too.
  if (saved ||
      result == LrcWriteResult.trashedNotWritten ||
      result == LrcWriteResult.trashTimedOut) {
    ref.invalidate(playingLocalLyricsProvider);
  }
  final preferEmbedded = ref
      .read(settingsProvider)
      .playback
      .preferEmbeddedLyrics;
  return (
    result: result,
    kept: saved && preferEmbedded ? LyricsChoiceKept.tagPreferred : null,
  );
}
