import '../lyrics.dart';

/// Why a song shows no lyrics.
enum LyricsNoneReason {
  /// Nothing local, nothing cached, and nothing to look up (or looking up
  /// is off).
  noLyrics,

  /// The provider was asked and has no match.
  notFound,

  /// The last lookup failed; nothing was stored.
  error,

  /// The user chose "Not these lyrics" for the song.
  skipped,

  /// The matching record says the song has no words.
  instrumental,
}

/// Where online lyrics came from, for the credit and the menu.
class OnlineLyricsOrigin {
  const OnlineLyricsOrigin({
    required this.providerId,
    required this.remoteId,
    required this.pinned,
    this.durationDelta,
  });

  final String providerId;
  final String remoteId;

  /// The user picked these lyrics (otherwise Kanaru matched them).
  final bool pinned;

  /// How far the record's length is from the song's; `null` when either is
  /// unknown.
  final Duration? durationDelta;

  @override
  bool operator ==(Object other) =>
      other is OnlineLyricsOrigin &&
      other.providerId == providerId &&
      other.remoteId == remoteId &&
      other.pinned == pinned &&
      other.durationDelta == durationDelta;

  @override
  int get hashCode => Object.hash(providerId, remoteId, pinned, durationDelta);
}

/// What the playing song's lyrics are right now. Every state belongs to the
/// song at [uri]; a consumer compares it with the playing uri.
sealed class PlayingLyricsStatus {
  const PlayingLyricsStatus(this.uri);

  final String uri;
}

/// Something is still being read (tags, files, the database).
final class LyricsReading extends PlayingLyricsStatus {
  const LyricsReading(super.uri);

  @override
  bool operator ==(Object other) => other is LyricsReading && other.uri == uri;

  @override
  int get hashCode => Object.hash(LyricsReading, uri);
}

/// A lookup is waiting to start or in flight at [providerId].
final class LyricsSearching extends PlayingLyricsStatus {
  const LyricsSearching(super.uri, this.providerId);

  final String providerId;

  @override
  bool operator ==(Object other) =>
      other is LyricsSearching &&
      other.uri == uri &&
      other.providerId == providerId;

  @override
  int get hashCode => Object.hash(LyricsSearching, uri, providerId);
}

/// Lyrics to show. [origin] is `null` for the song's own tags or `.lrc`.
final class LyricsFound extends PlayingLyricsStatus {
  const LyricsFound(super.uri, this.lyrics, {this.origin});

  final Lyrics lyrics;
  final OnlineLyricsOrigin? origin;

  /// Same instance of [lyrics], so a view keyed on it keeps its state.
  @override
  bool operator ==(Object other) =>
      other is LyricsFound &&
      other.uri == uri &&
      identical(other.lyrics, lyrics) &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(LyricsFound, uri, identityHashCode(lyrics));
}

/// No lyrics to show. [origin] is set for an instrumental record.
final class LyricsNone extends PlayingLyricsStatus {
  const LyricsNone(super.uri, this.reason, {this.origin});

  final LyricsNoneReason reason;
  final OnlineLyricsOrigin? origin;

  @override
  bool operator ==(Object other) =>
      other is LyricsNone &&
      other.uri == uri &&
      other.reason == reason &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(LyricsNone, uri, reason, origin);
}
