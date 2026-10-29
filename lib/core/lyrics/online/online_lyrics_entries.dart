import '../../database/library_database.dart';
import '../../database/online_lyrics_queries.dart';
import '../lrc_parser.dart';
import '../lyrics.dart';
import 'lyrics_choice.dart';

/// The first of [synced] and [plain] that parses into lyrics: the text and
/// what it parses to. The synced text wins; the plain text is the fallback
/// when the synced one is absent or has no usable line. Online text is shown
/// like a `.lrc` file, so it carries [LyricsSource.sidecar].
({String text, Lyrics lyrics})? _firstParsed(String? synced, String? plain) {
  for (final text in [synced, plain]) {
    if (text == null || text.trim().isEmpty) continue;
    final lyrics = parseLyricsText(text, LyricsSource.sidecar);
    if (lyrics != null) return (text: text, lyrics: lyrics);
  }
  return null;
}

/// Parses stored lyrics text once, by the rule of [storedLyricsText].
Lyrics? parseStoredLyrics({String? synced, String? plain}) =>
    _firstParsed(synced, plain)?.lyrics;

/// The stored text the app shows: the first of [synced] and [plain] that
/// parses, `null` when neither does. The `.lrc` writer saves this same text,
/// so a saved file shows what was on screen.
String? storedLyricsText({String? synced, String? plain}) =>
    _firstParsed(synced, plain)?.text;

/// A song's stored choice and pick, with the text already parsed. The pick
/// fields are all `null` while the song has a choice but no pick.
class LyricsPinEntry {
  const LyricsPinEntry({
    required this.pinnedAt,
    this.choice = LyricsChoice.auto,
    this.providerId,
    this.remoteId,
    this.lyrics,
    this.instrumental = false,
    this.remoteDurationMs,
  });

  factory LyricsPinEntry.fromRow(LyricsPinRow row) => LyricsPinEntry(
    pinnedAt: row.pinnedAt,
    choice: parseLyricsChoice(row.mode),
    providerId: row.providerId,
    remoteId: row.remoteId,
    lyrics: parseStoredLyrics(synced: row.syncedText, plain: row.plainText),
    instrumental: row.instrumental,
    remoteDurationMs: row.remoteDurationMs,
  );

  final int pinnedAt;
  final LyricsChoice choice;
  final String? providerId;
  final String? remoteId;

  /// `null` without a pick, for an instrumental pick or text with no usable
  /// line.
  final Lyrics? lyrics;
  final bool instrumental;
  final int? remoteDurationMs;

  /// The song has a stored pick (usable or not).
  bool get hasPick => remoteId != null;
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
