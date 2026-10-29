import '../../database/artist_names.dart';
import '../../database/text_keys.dart';
import 'lyrics_match_keys.dart';
import 'lyrics_match_similarity.dart';

/// Artist names that stand for "nobody in particular", after `foldArtist`.
const _unknownArtists = {
  'unknown artist',
  'unknown',
  'various',
  'various artist',
  'various artists',
  'nhieu ca si',
  'va',
  'v a',
};

/// Names of this many code points or fewer (after folding) must be equal.
/// Stated explicitly even though `similarity` already scores such unequal
/// pairs 0 (`B` vs `BB`), so the rule survives a change of the threshold.
const _shortNameMax = 2;

/// Whether [artist] is a placeholder such as "Unknown Artist" or "Various
/// Artists", not a name.
bool isUnknownArtist(String artist) {
  final folded = foldArtist(artist);
  return _unknownArtists.contains(folded) ||
      _unknownArtists.contains(sortKey(artist).trim());
}

bool _namesMatch(String mine, String theirs) {
  if (mine == theirs) return true;
  if (mine.runes.length <= _shortNameMax ||
      theirs.runes.length <= _shortNameMax) {
    return false;
  }
  return atLeast(similarity(mine, theirs), artistSimilarityMin);
}

/// Whether the library's artist tag [local] and the record's artist string
/// [remote] share a person: the two strings are equal as wholes (`Earth,
/// Wind & Fire`), or any name of the tag equals or is `artistSimilarityMin`
/// similar to any name of the record. Placeholder names never count.
bool artistMatches(String? local, String remote) {
  if (local == null) return false;
  final remoteFull = foldArtist(remote);
  final localFull = foldArtist(local);
  if (localFull.isEmpty || remoteFull.isEmpty) return false;
  if (!isUnknownArtist(local) && localFull == remoteFull) return true;
  final theirs = [
    for (final name in remoteArtistNames(remote))
      if (!isUnknownArtist(name)) foldArtist(name),
  ]..removeWhere((n) => n.isEmpty);
  for (final name in splitArtists(local)) {
    if (isUnknownArtist(name)) continue;
    final mine = foldArtist(name);
    if (mine.isEmpty) continue;
    if (theirs.any((t) => _namesMatch(mine, t))) return true;
  }
  return false;
}
