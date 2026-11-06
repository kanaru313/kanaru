part of 'lyrics_search_controller.dart';

/// Loading the rejected results of the song and ranking the raw answers of
/// the providers, for [LyricsSearchController].
mixin _SearchRanking on Notifier<LyricsSearchState> {
  LyricsTarget get target;
  Map<String, List<LyricsCandidate>> get _raw;
  Set<({String providerId, String remoteId})> get _bodyMissing;
  set _rejected(Set<({String providerId, String remoteId})> value);
  Set<({String providerId, String remoteId})> get _rejected;
  set _rejectedHashes(Set<String> value);
  Set<String> get _rejectedHashes;

  Future<void> _loadRejected() async {
    try {
      final matches = await ref
          .read(libraryDatabaseProvider)
          ?.rejectedMatches(target.cacheKey);
      _rejected = {
        for (final (providerId, remoteId)
            in matches?.ids ?? const <(String, String)>{})
          (providerId: providerId, remoteId: remoteId),
      };
      _rejectedHashes = matches?.hashes ?? const <String>{};
    } on Object catch (e) {
      _log.warning('could not read rejected lyrics: ${e.runtimeType}');
      _rejected = const {};
      _rejectedHashes = const {};
    }
  }

  // [keep] is a hand-picked result: it stays listed even when the ranking
  // would push it past the limit.
  List<RankedCandidate> _rank({({String providerId, String remoteId})? keep}) {
    final ranked = rankCandidates(
      target.query,
      [for (final list in _raw.values) ...list],
      rejected: _rejected,
      rejectedHashes: _rejectedHashes,
      keepRejected: true,
    );
    final top = ranked.take(maxSearchResults).toList();
    if (keep != null && !top.any((m) => m.candidate.ref == keep)) {
      final kept = ranked.where((m) => m.candidate.ref == keep);
      if (kept.isNotEmpty) top.add(kept.first);
    }
    return [
      for (final m in top)
        RankedCandidate(
          m.candidate,
          m,
          bodyMissing: _bodyMissing.contains(m.candidate.ref),
        ),
    ];
  }
}
