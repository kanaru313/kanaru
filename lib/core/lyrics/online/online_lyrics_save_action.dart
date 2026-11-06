import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_startup.dart';
import '../../database/online_lyrics_queries.dart';
import '../../lyrics_translation/lyrics_content_hash.dart';
import '../../settings/settings_provider.dart';
import '../embedded_lyrics_reader.dart';
import '../lrc_sidecar_reader.dart';
import '../lyrics.dart';
import '../lyrics_loader.dart';
import '../playing_local_lyrics_provider.dart';
import 'lrc_sidecar_writer.dart';
import 'lyrics_provider.dart';
import 'lyrics_target.dart';
import 'online_lyrics_entries.dart';
import 'playing_lyrics_status.dart';

/// Why the song keeps its chosen lyrics after a save.
enum LyricsChoiceKept {
  /// The saved file is not what shows: the song's tags win because
  /// "prefer embedded lyrics" is on.
  tagPreferred,

  /// The saved file is not what shows: Kanaru reads a different file of the
  /// song (a `.LRC` next to the `.lrc` that was saved, say).
  otherFile,
}

/// The result of a save. [result] is `null` when the stored text is gone (it
/// changed since the menu opened). [kept] is set only after `written` or
/// `identical`, when the saved file is not the local lyrics that show.
typedef LyricsSaveOutcome = ({LrcWriteResult? result, LyricsChoiceKept? kept});

const _noText = (result: null, kept: null);

/// Saves the stored text of [origin] as the song's `.lrc` file.
///
/// After `written` or `identical` the song's own lyrics are read again with
/// the current "prefer embedded lyrics" setting. The pick and the choice
/// always stay, so a pinned online version keeps showing; the file is the
/// song's local lyrics from now on. When another file or the tags win over
/// the saved one, [LyricsSaveOutcome.kept] says why (not when the song's pick
/// is the saved record: the pick wins and keeps showing). File errors come
/// back as results, never as exceptions; a database error propagates.
Future<LyricsSaveOutcome> saveOnlineLyrics(
  Ref ref,
  LyricsTarget target,
  OnlineLyricsOrigin origin, {
  bool replace = false,
}) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return (result: LrcWriteResult.outsideLibrary, kept: null);
  final stored = await db.storedOnlineLyricsText(
    trackKey: target.trackKey,
    cacheKey: target.cacheKey,
    providerId: origin.providerId,
    remoteId: origin.remoteId,
  );
  if (stored == null) return _noText;
  final path = target.path;
  if (path == null) return (result: LrcWriteResult.outsideLibrary, kept: null);
  final savedLyrics = parseStoredLyrics(
    synced: stored.synced,
    plain: stored.plain,
  );
  final result = await ref
      .read(lrcSidecarWriterProvider)
      .write(
        path,
        LyricsBody(
          syncedLrc: stored.synced,
          plain: stored.plain,
          instrumental: stored.instrumental,
        ),
        replace: replace,
      );
  final saved =
      result == LrcWriteResult.written || result == LrcWriteResult.identical;
  if (!ref.mounted) return (result: result, kept: null);
  // The old file may be in the trash: read the song's own lyrics again so
  // the menu stops offering a file that is gone.
  if (result == LrcWriteResult.trashedNotWritten ||
      result == LrcWriteResult.trashTimedOut) {
    ref.invalidate(playingLocalLyricsProvider);
  }
  if (!saved || savedLyrics == null) return (result: result, kept: null);
  ref.invalidate(playingLocalLyricsProvider);
  final preferEmbedded = ref
      .read(settingsProvider)
      .playback
      .preferEmbeddedLyrics;
  final reread = await loadLyrics(
    path,
    preferEmbedded: preferEmbedded,
    embedded: ref.read(embeddedLyricsReaderProvider),
    sidecar: ref.read(lrcSidecarReaderProvider),
  );
  if (!ref.mounted) return (result: result, kept: null);
  final isSavedFile =
      reread != null &&
      reread.source == LyricsSource.sidecar &&
      lyricsContentHashOf(reread) == lyricsContentHashOf(savedLyrics);
  if (isSavedFile) {
    return (result: result, kept: null);
  }
  final pin = await db.watchLyricsPin(target.trackKey).first;
  if (!ref.mounted) return (result: result, kept: null);
  final pickIsSaved =
      pin != null &&
      pin.providerId == origin.providerId &&
      pin.remoteId == origin.remoteId;
  if (pickIsSaved) return (result: result, kept: null);
  final fromTags = reread?.source == LyricsSource.embedded && preferEmbedded;
  return (
    result: result,
    kept: fromTags ? LyricsChoiceKept.tagPreferred : LyricsChoiceKept.otherFile,
  );
}
