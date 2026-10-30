import 'package:drift/drift.dart' show Value;

import '../../database/library_database.dart';
import '../../database/online_lyrics_queries.dart';
import 'lyrics_candidate_checks.dart';
import 'lyrics_fetch_exception.dart';
import 'lyrics_http.dart';
import 'lyrics_http_retry.dart';
import 'lyrics_match.dart';
import 'lyrics_provider.dart';
import 'lyrics_provider_registry.dart';
import 'lyrics_target.dart';

/// What a finished lookup stored. [notStored] means the answer was refused by
/// the database because the plugin source was removed (or uninstalled) while
/// the lookup ran: nothing was written, so the lookup neither found nor
/// missed.
enum OnlineLyricsLookupResult { found, notFound, notStored }

/// Most `fetch` calls one lookup makes for matches that came without lyrics.
const maxLookupFetches = 3;

/// Looks [target] up at one provider and stores a whitelisted answer. Every
/// answer of the provider first goes through the host checks
/// (`lyrics_candidate_checks.dart`); a non-empty list of nothing valid
/// throws `LyricsFetchException(invalidResponse)`.
///
/// * `lookup` returns a record that passes the match gate: a found row;
/// * otherwise the provider's `search` runs (by title, and by artist when the
///   tag has one; the gate checks the artists); its best record that passes
///   the gate: a found row;
/// * the `lookup` said "not found" (or its record failed the gate) and the
///   `search` returned a valid list with no record passing: a not-found row.
///
/// A record that passes the gate on its metadata but came without lyrics (a
/// two-step source) has its lyrics fetched: the good matches are tried in
/// rank order, at most [maxLookupFetches] fetches, and the first with lyrics
/// (or the instrumental flag) that is not a duplicate of a rejected text
/// wins. If none has any, the result is not found.
///
/// A plain-only `lookup` record also runs the `search`; its best good match
/// replaces the record when that one has synced text (a match without lyrics
/// counts only after its fetch): two requests for LRCLIB, three when the best
/// match has to be fetched. If that extra search or fetch fails with a
/// `LyricsFetchException` other than `notConsented`, the plain record is
/// kept.
///
/// A plugin source's row is saved only while its record exists and is not
/// removed; when the database refuses it the result is [notStored], never
/// `found`.
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
  final providerId = registration.id;

  LyricsMatch judge(LyricsCandidate c) => matchCandidate(
    query,
    c,
    rejected: rejected,
    rejectedHashes: rejectedHashes,
  );
  var fetches = 0;
  // The lyrics of a match that came without; null when the provider has none
  // or the text is a duplicate of a rejected one.
  Future<LyricsCandidate?> fetchBody(LyricsCandidate c) async {
    fetches++;
    final body = checkFetchedBody(await provider.fetch(c.remoteId, http));
    if (body == null) return null;
    final withBody = c.withBody(body);
    return judge(withBody).goodMatch ? withBody : null;
  }

  LyricsCandidate? chosen;
  final exact = checkLookupCandidate(
    await provider.lookup(query, http),
    providerId: providerId,
  );
  final exactIsGood = exact != null && judge(exact).goodMatch;
  // A good exact record without lyrics is fetched like a search result.
  final exactBodyless = exactIsGood && !exact.hasBody;
  // A plain-only exact hit may have a synced twin in the search: two requests
  // for LRCLIB, three when the best match has to be fetched.
  final exactNeedsSynced =
      exactIsGood &&
      !exactBodyless &&
      exact.body?.syncedLrc == null &&
      !(exact.body?.instrumental ?? false);
  if (exactIsGood && !exactBodyless) chosen = exact;
  if (!exactIsGood || exactBodyless || exactNeedsSynced) {
    try {
      final searched = checkCandidates(
        await provider.search(query, http),
        providerId: providerId,
      );
      final ranked = rankCandidates(
        query,
        [
          if (exactBodyless) exact,
          for (final c in searched)
            if (!exactBodyless || c.ref != exact.ref) c,
        ],
        rejected: rejected,
        rejectedHashes: rejectedHashes,
      );
      final good = [
        for (final m in ranked)
          if (m.goodMatch) m.candidate,
      ];
      if (exactNeedsSynced) {
        // Only the best match is looked at, and only its synced text counts.
        final best = good.firstOrNull;
        final upgrade = best == null || best.hasBody
            ? best
            : await fetchBody(best);
        if (upgrade?.body?.syncedLrc != null) chosen = upgrade;
      } else {
        for (final c in good) {
          if (c.hasBody) {
            chosen = c;
            break;
          }
          if (fetches >= maxLookupFetches) break;
          chosen = await fetchBody(c);
          if (chosen != null) break;
        }
      }
    } on LyricsFetchException catch (e) {
      // The plain hit is already good; a failed bonus search must not lose it.
      if (!exactNeedsSynced || e.kind == LyricsFetchKind.notConsented) rethrow;
    } on LyricsRequestAbandoned {
      // Abandoned before the bonus request went out: keep the plain hit.
      if (!exactNeedsSynced) rethrow;
    } on LyricsSourceSkipped {
      // The source could not run the bonus request: keep the plain hit.
      if (!exactNeedsSynced) rethrow;
    }
  }

  final fetchedAt = now().millisecondsSinceEpoch;
  final body = chosen?.body;
  if (chosen == null || body == null) {
    final saved = await db.saveOnlineLyrics(
      OnlineLyricsCompanion.insert(
        cacheKey: cacheKey,
        providerId: registration.id,
        status: OnlineLyricsStatus.notFound.value,
        fetchedAt: fetchedAt,
      ),
    );
    return saved
        ? OnlineLyricsLookupResult.notFound
        : OnlineLyricsLookupResult.notStored;
  }
  final saved = await db.saveOnlineLyrics(
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
  return saved
      ? OnlineLyricsLookupResult.found
      : OnlineLyricsLookupResult.notStored;
}
