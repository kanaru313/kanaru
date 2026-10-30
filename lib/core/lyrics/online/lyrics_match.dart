import 'candidate_content_hash.dart';
import 'lyrics_artist_match.dart';
import 'lyrics_candidate_checks.dart';
import 'lyrics_match_keys.dart';
import 'lyrics_match_similarity.dart';
import 'lyrics_provider.dart';

export 'lyrics_artist_match.dart' show isUnknownArtist;
export 'lyrics_match_similarity.dart';

/// Largest difference between the song's and the record's duration, inclusive.
const maxDurationDelta = Duration(seconds: 3);

/// A candidate with its verdict for one query.
class LyricsMatch {
  const LyricsMatch({
    required this.candidate,
    required this.score,
    required this.delta,
    required this.goodMatch,
    required this.metadataGood,
    this.rejected = false,
  });

  final LyricsCandidate candidate;

  /// Title similarity, 0 to 1.
  final double score;

  /// Absolute duration difference; `null` when either side has no duration.
  final Duration? delta;

  /// Title, artist and duration pass and the record is not rejected,
  /// whatever its body.
  final bool metadataGood;

  /// [metadataGood] and, when the record came with a body, a body with
  /// lyrics or the instrumental flag: safe to use without asking. A record
  /// with no body at all (a two-step source answers the search without
  /// lyrics) is judged by its metadata only; its body is fetched next and
  /// checked then.
  final bool goodMatch;

  /// The user marked this record "Not these lyrics" for the song. Only a
  /// search that keeps rejected records ever shows such a match.
  final bool rejected;
}

/// Whether [query] has what an automatic search needs: a title, a real
/// artist (not "Unknown Artist") and a duration. Without an artist tag only
/// the manual search runs.
bool isAutoSearchable(LyricsQuery query) {
  final title = query.title?.trim() ?? '';
  final artist = primaryArtist(query.artist)?.trim() ?? '';
  final duration = query.duration;
  if (title.isEmpty || artist.isEmpty) return false;
  if (duration == null || duration <= Duration.zero) return false;
  return !isUnknownArtist(artist);
}

/// Judges [candidate] against [query]. The gate needs: duration within
/// [maxDurationDelta] (skipped when [query] has no duration, as in a manual
/// search), title equal, joined-equal or [titleSimilarityMin] similar, the
/// artist rule, and lyrics or the instrumental flag (a record with no body
/// at all passes on its metadata; see [LyricsMatch.goodMatch]). A record in
/// [rejected], or whose text hashes into [rejectedHashes] (a duplicate of a
/// rejected record, see `candidateContentHash`), never matches.
LyricsMatch matchCandidate(
  LyricsQuery query,
  LyricsCandidate candidate, {
  Set<({String providerId, String remoteId})> rejected = const {},
  Set<String> rejectedHashes = const {},
}) {
  final wanted = query.duration;
  final has = candidate.duration;
  final delta = wanted == null || has == null
      ? null
      : Duration(microseconds: (wanted - has).inMicroseconds.abs());
  final durationOk =
      wanted == null || (delta != null && delta <= maxDurationDelta);
  final title = query.title?.trim() ?? '';
  var score = 0.0;
  var titleOk = false;
  if (title.isNotEmpty) {
    final mine = normalizeTitle(title);
    final theirs = normalizeTitle(candidate.title);
    score = similarity(mine, theirs);
    titleOk =
        mine.isNotEmpty &&
        theirs.isNotEmpty &&
        (atLeast(score, titleSimilarityMin) ||
            joinedTitle(mine) == joinedTitle(theirs));
  }
  final isRejected = _isRejected(candidate, rejected, rejectedHashes);
  final bodyOk = candidate.body == null || candidate.hasBody;
  final metadataGood =
      !isRejected &&
      durationOk &&
      titleOk &&
      artistMatches(query.artist, candidate.artist);
  return LyricsMatch(
    candidate: candidate,
    score: score,
    delta: delta,
    rejected: isRejected,
    metadataGood: metadataGood,
    goodMatch: metadataGood && bodyOk,
  );
}

bool _isRejected(
  LyricsCandidate candidate,
  Set<({String providerId, String remoteId})> rejected,
  Set<String> rejectedHashes,
) {
  if (rejected.contains(candidate.ref)) return true;
  if (rejectedHashes.isEmpty) return false;
  final hash = candidateContentHash(candidate);
  return hash != null && rejectedHashes.contains(hash);
}

int _bodyRank(LyricsBody? body) {
  if (body?.syncedLrc != null) return 0;
  if (body?.plain != null) return 1;
  return body != null && body.instrumental ? 2 : 3;
}

/// Judges every candidate not in [rejected] (by id or text, [rejectedHashes])
/// and orders them: good matches first, then synced before plain before
/// instrumental before a record without lyrics (a body-less record ranks
/// after every one with a body), smaller duration difference, higher title
/// similarity, and the given order for ties. With [keepRejected] (the manual search) records
/// in [rejected] stay in the list, flagged and after every other one;
/// automatic lookups leave it off.
List<LyricsMatch> rankCandidates(
  LyricsQuery query,
  Iterable<LyricsCandidate> candidates, {
  Set<({String providerId, String remoteId})> rejected = const {},
  Set<String> rejectedHashes = const {},
  bool keepRejected = false,
}) {
  final indexed = <(int, LyricsMatch)>[
    for (final (i, c) in candidates.indexed)
      (
        i,
        matchCandidate(
          query,
          c,
          rejected: rejected,
          rejectedHashes: rejectedHashes,
        ),
      ),
  ];
  if (!keepRejected) indexed.removeWhere((e) => e.$2.rejected);
  indexed.sort((a, b) {
    final x = a.$2;
    final y = b.$2;
    if (x.rejected != y.rejected) return x.rejected ? 1 : -1;
    if (x.goodMatch != y.goodMatch) return x.goodMatch ? -1 : 1;
    final body = _bodyRank(x.candidate.body)
        .compareTo(_bodyRank(y.candidate.body));
    if (body != 0) return body;
    if (x.delta != y.delta) {
      if (x.delta == null) return 1;
      if (y.delta == null) return -1;
      return x.delta!.compareTo(y.delta!);
    }
    final score = y.score.compareTo(x.score);
    return score != 0 ? score : a.$1.compareTo(b.$1);
  });
  return [for (final (_, m) in indexed) m];
}
