import 'package:drift/drift.dart' show Value;

import '../../database/library_database.dart';
import '../../database/online_lyrics_queries.dart';
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
/// * otherwise the provider's `search` runs; its best record that passes the
///   gate: a found row;
/// * the `lookup` said "not found" (or its record failed the gate) and the
///   `search` returned a valid list with no record passing: a not-found row.
///
/// Rejected records are excluded from both the gate and the ranking. Any
/// failure throws (a `LyricsFetchException` for the network side) and writes
/// nothing, so an error is never remembered as "no lyrics". The target must
/// be [LyricsTarget.isAutoSearchable].
Future<OnlineLyricsLookupResult> runOnlineLyricsLookup({
  required LyricsProviderRegistration registration,
  required LyricsHttp http,
  required LibraryDatabase db,
  required DateTime Function() now,
  required LyricsTarget target,
}) async {
  final query = target.query;
  final cacheKey = target.cacheKey;
  final rejected = {
    for (final (providerId, remoteId) in (await db.rejectedMatches(
      cacheKey,
    )).ids)
      (providerId: providerId, remoteId: remoteId),
  };
  final provider = registration.provider;

  LyricsCandidate? chosen;
  final exact = await provider.lookup(query, http);
  if (exact != null &&
      matchCandidate(query, exact, rejected: rejected).goodMatch) {
    chosen = exact;
  } else {
    final found = await provider.search(query, http);
    final ranked = rankCandidates(query, found, rejected: rejected);
    if (ranked.isNotEmpty && ranked.first.goodMatch) {
      chosen = ranked.first.candidate;
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
