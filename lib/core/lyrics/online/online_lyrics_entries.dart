import '../../database/library_database.dart';
import '../../database/online_lyrics_queries.dart';
import '../lrc_parser.dart';
import '../lyrics.dart';

/// Parses stored lyrics text once. The synced text wins; the plain text is
/// the fallback when the synced one is absent or has no usable line. Online
/// text is shown like a `.lrc` file, so it carries [LyricsSource.sidecar].
Lyrics? parseStoredLyrics({String? synced, String? plain}) {
  for (final text in [synced, plain]) {
    if (text == null || text.trim().isEmpty) continue;
    final lyrics = parseLyricsText(text, LyricsSource.sidecar);
    if (lyrics != null) return lyrics;
  }
  return null;
}

/// A song's pick, with its text already parsed. A [remoteId] of `null` is a
/// skip: the user chose no online lyrics for the song.
class LyricsPinEntry {
  const LyricsPinEntry({
    required this.pinnedAt,
    this.providerId,
    this.remoteId,
    this.lyrics,
    this.instrumental = false,
    this.remoteDurationMs,
  });

  factory LyricsPinEntry.fromRow(LyricsPinRow row) => LyricsPinEntry(
    pinnedAt: row.pinnedAt,
    providerId: row.providerId,
    remoteId: row.remoteId,
    lyrics: parseStoredLyrics(synced: row.syncedText, plain: row.plainText),
    instrumental: row.instrumental,
    remoteDurationMs: row.remoteDurationMs,
  );

  final int pinnedAt;
  final String? providerId;
  final String? remoteId;

  /// `null` for a skip, an instrumental pick or text with no usable line.
  final Lyrics? lyrics;
  final bool instrumental;
  final int? remoteDurationMs;

  bool get isSkip => remoteId == null;
}

/// One provider's cached answer for a metadata key, text already parsed.
class OnlineLyricsEntry {
  const OnlineLyricsEntry({
    required this.providerId,
    required this.status,
    required this.fetchedAt,
    this.remoteId,
    this.lyrics,
    this.instrumental = false,
    this.remoteDurationMs,
  });

  factory OnlineLyricsEntry.fromRow(
    OnlineLyricsRow row,
    OnlineLyricsStatus status,
  ) => OnlineLyricsEntry(
    providerId: row.providerId,
    status: status,
    fetchedAt: row.fetchedAt,
    remoteId: row.remoteId,
    lyrics: parseStoredLyrics(synced: row.syncedText, plain: row.plainText),
    instrumental: row.instrumental,
    remoteDurationMs: row.remoteDurationMs,
  );

  final String providerId;
  final OnlineLyricsStatus status;
  final int fetchedAt;
  final String? remoteId;

  /// `null` for a not-found or instrumental entry, or text with no usable
  /// line (a found entry with neither this nor [instrumental] is unusable).
  final Lyrics? lyrics;
  final bool instrumental;
  final int? remoteDurationMs;
}
