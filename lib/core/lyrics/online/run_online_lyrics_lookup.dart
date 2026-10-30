import 'package:drift/drift.dart' show Value;

import '../../database/library_database.dart';
import '../../database/online_lyrics_queries.dart';
import 'lyrics_fetch_exception.dart';
import 'lyrics_http.dart';
import 'lyrics_match.dart';
import 'lyrics_provider.dart';
import 'lyrics_provider_registry.dart';
import 'lyrics_target.dart';

/// What a finished lookup stored.
enum OnlineLyricsLookupResult { found, notFound }

/// Looks [target] up at one provider and stores a whitelisted answer:
///
/// * `lookup` returns a record that passes the match gate: a found row;
/// * otherwise the provider's `search` runs (by title, and by artist when the
///   tag has one; the gate checks the artists); its best record that passes
///   the gate: a found row;
/// * the `lookup` said "not found" (or its record failed the gate) and the
///   `search` returned a valid list with no record passing: a not-found row.
///
/// A plain-only `lookup` record also runs the `search`; its best good match
/// replaces the record when that one has synced text. If that extra search
/// fails with a `LyricsFetchException` other than `notConsented`, the plain
/// record is kept.
///
/// Rejected records, and duplicates of their text, are excluded from both the
/// gate and the ranking. Any other failure throws (a `LyricsFetchException`
/// for the network side) and writes nothing, so an error is never remembered
/// as "no lyrics". The target must be [LyricsTarget.isAutoSearchable].
Future<OnlineLyricsLookupResult> runOnlineLyricsLookup({
  required LyricsProviderRegistration registration,
  required LyricsHttp http,
  required LibraryDatabase db,
  required DateTime Function() now,
  required LyricsTarget target,
}) async {
  final query = target.query;
  final cacheKey = target.cacheKey;
  final rejects = await db.rejectedMatches(cacheKey);
  final rejected = {
    for (final (providerId, remoteId) in rejects.ids)
      (providerId: providerId, remoteId: remoteId),
  };
  final rejectedHashes = rejects.hashes;
  final provider = registration.provider;

  LyricsCandidate? chosen;
  final exact = await provider.lookup(query, http);
  final exactIsGood =
      exact != null &&
      matchCandidate(
        query,
        exact,
        rejected: rejected,
        rejectedHashes: rejectedHashes,
      ).goodMatch;
  // A plain-only exact hit may have a synced twin in the search; at most two
  // requests either way.
  final exactNeedsSynced =
      exactIsGood &&
      exact.body?.syncedLrc == null &&
      !(exact.body?.instrumental ?? false);
  if (exactIsGood) chosen = exact;
  if (!exactIsGood || exactNeedsSynced) {
    List<LyricsCandidate> found = const [];
    try {
      found = await provider.search(query, http);
    } on LyricsFetchException catch (e) {
      // The plain hit is already good; a failed bonus search must not lose it.
      if (!exactNeedsSynced || e.kind == LyricsFetchKind.notConsented) rethrow;
    }
    final ranked = rankCandidates(
      query,
      found,
      rejected: rejected,
      rejectedHashes: rejectedHashes,
    );
    if (ranked.isNotEmpty && ranked.first.goodMatch) {
      final best = ranked.first.candidate;
      if (!exactNeedsSynced || best.body?.syncedLrc != null) chosen = best;
    }
  }

  final fetchedAt = now().millisecondsSinceEpoch;
  if (chosen == null) {
    await db.saveOnlineLyrics(
      OnlineLyricsCompanion.insert(
        cacheKey: cacheKey,
        providerId: registration.id,
        status: OnlineLyricsStatus.notFound.value,
        fetchedAt: fetchedAt,
      ),
    );
    return OnlineLyricsLookupResult.notFound;
  }
  final body = chosen.body!;
  await db.saveOnlineLyrics(
    OnlineLyricsCompanion.insert(
      cacheKey: cacheKey,
      providerId: registration.id,
      status: OnlineLyricsStatus.found.value,
      remoteId: Value(chosen.remoteId),
      syncedText: Value(body.syncedLrc),
      plainText: Value(body.plain),
      instrumental: Value(body.instrumental),
      remoteDurationMs: Value(chosen.duration?.inMilliseconds),
      fetchedAt: fetchedAt,
    ),
  );
  return OnlineLyricsLookupResult.found;
}
