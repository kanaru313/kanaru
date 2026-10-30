import 'lyrics_http.dart';

/// What to look for: the tags of a local song, or a free-text [text] typed by
/// the user in the manual search.
class LyricsQuery {
  const LyricsQuery({
    this.title,
    this.artist,
    this.album,
    this.duration,
    this.text,
  });

  final String? title;
  final String? artist;
  final String? album;
  final Duration? duration;

  /// Free-text query of the manual search; when set, a provider searches by
  /// it and ignores the structured fields.
  final String? text;
}

/// The lyrics of a [LyricsCandidate]. [syncedLrc] and [plain] are `null` when
/// absent or blank.
class LyricsBody {
  const LyricsBody({this.syncedLrc, this.plain, this.instrumental = false});

  final String? syncedLrc;
  final String? plain;

  /// The provider says the song has no words.
  final bool instrumental;

  bool get hasLyrics => syncedLrc != null || plain != null;
}

/// A provider's record, checked by the host.
class LyricsCandidate {
  const LyricsCandidate({
    required this.providerId,
    required this.remoteId,
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.body,
  });

  final String providerId;

  /// Identifies the record inside its provider.
  final String remoteId;
  final String title;
  final String artist;
  final String? album;
  final Duration? duration;
  final LyricsBody? body;

  /// What a rejected record is remembered by.
  ({String providerId, String remoteId}) get ref =>
      (providerId: providerId, remoteId: remoteId);
}

/// A source of online lyrics. "Dumb provider, smart host": a provider only
/// turns a query into requests and answers into [LyricsCandidate]s; the host
/// owns consent, matching, caching and files.
///
/// Rules every implementation follows:
///
/// * stateless: no field changes between calls, nothing is remembered;
/// * async: every method returns a future and never blocks;
/// * no I/O except through the [LyricsHttp] it is given, which only reaches
///   the hosts the provider registered with;
/// * [id], [displayName] and [hosts] are read once, when the provider is
///   registered; later changes are ignored;
/// * every failure is a `LyricsFetchException`, never a raw error, and only
///   an answer the service documents may be reported as "not found";
/// * a `LyricsRequestAbandoned` thrown by [LyricsHttp] passes through
///   unwrapped, and a `LyricsRequestRejected` from `http.send` is mapped to
///   a `LyricsFetchException`;
/// * `search` and `lookup` may return records whose `body` is null; the host
///   then gets the lyrics with `fetch`, where null means no lyrics;
/// * the host checks all output before it is shown or stored.
abstract interface class LyricsProvider {
  /// Short stable name, used in the cache.
  String get id;

  String get displayName;

  /// Bare host names (no scheme, no port) the provider talks to.
  List<String> get hosts;

  /// The record that exactly matches [query], or `null` when the service
  /// says it has none.
  Future<LyricsCandidate?> lookup(LyricsQuery query, LyricsHttp http);

  /// Records that may match [query], best guesses first, at most 20.
  Future<List<LyricsCandidate>> search(LyricsQuery query, LyricsHttp http);

  /// The lyrics of the record [remoteId], or `null` when it does not exist.
  Future<LyricsBody?> fetch(String remoteId, LyricsHttp http);
}
