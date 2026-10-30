part of 'lyrics_search_controller.dart';

/// Getting the lyrics of a search result that came without any (a two-step
/// source), for [LyricsSearchController]. The members below are the
/// controller's own state, declared here so the methods can use them.
mixin _SearchBodyFetch on Notifier<LyricsSearchState> {
  LyricsTarget get target;
  Map<String, List<LyricsCandidate>> get _raw;
  Set<({String providerId, String remoteId})> get _rejected;
  Set<String> get _rejectedHashes;
  Set<({String providerId, String remoteId})> get _bodyMissing;
  bool get _autoSelected;
  int get _autoFetches;
  set _autoFetches(int count);
  bool _current(int generation);

  /// Fetches the lyrics of [result] when it came without any, was not asked
  /// yet and is not being asked.
  Future<void> _ensureBody(RankedCandidate result, int generation) async {
    final candidate = result.candidate;
    if (candidate.body != null || result.bodyMissing) return;
    if (state.bodyFetches[candidate.ref]?.phase == BodyFetchPhase.loading) {
      return;
    }
    if (_autoSelected) {
      if (_autoFetches >= maxLookupFetches) return;
      _autoFetches++;
    }
    final registration = ref
        .read(lyricsProvidersProvider)
        .where((r) => r.id == candidate.providerId)
        .firstOrNull;
    _setFetch(candidate, const BodyFetchState(BodyFetchPhase.loading));
    LyricsBody? body;
    try {
      if (registration == null) {
        throw const LyricsFetchException(LyricsFetchKind.blockedHost);
      }
      final http = ref
          .read(onlineLyricsHttpFactoryProvider)
          .forManual(registration, abandoned: () => !_current(generation));
      body = checkFetchedBody(
        await registration.provider.fetch(candidate.remoteId, http),
      );
    } on LyricsRequestAbandoned {
      return;
    } on LyricsSourceSkipped {
      // Did not run: back to "not fetched", so selecting it tries again.
      if (_current(generation)) {
        state = state.copyWith(
          selected: state.selected,
          bodyFetches: {...state.bodyFetches}..remove(candidate.ref),
        );
      }
      return;
    } on LyricsFetchException catch (e) {
      if (_current(generation)) {
        _setFetch(candidate, BodyFetchState(BodyFetchPhase.failed, e.kind));
      }
      return;
    } on Object catch (e) {
      _log.warning('lyrics fetch failed: ${e.runtimeType}');
      if (_current(generation)) {
        _setFetch(candidate, const BodyFetchState(BodyFetchPhase.failed));
      }
      return;
    }
    if (!_current(generation)) return;
    if (body == null) {
      _bodyMissing.add(candidate.ref);
    } else {
      final list = _raw[candidate.providerId] ?? const [];
      _raw[candidate.providerId] = [
        for (final c in list)
          c.remoteId == candidate.remoteId ? c.withBody(body) : c,
      ];
    }
    // The list keeps its order: the fetched result is updated in place.
    final results = [
      for (final r in state.results)
        r.candidate.ref == candidate.ref ? _judge(candidate, body) : r,
    ];
    // An automatic pick whose fetched text turns out to be a rejected one, or
    // that has no lyrics, gives way to the next usable result, until the
    // fetch cap of the search is spent (then the selection stays).
    final current = state.selected;
    final next =
        _autoSelected &&
            _autoFetches < maxLookupFetches &&
            current != null &&
            results[current].candidate.ref == candidate.ref &&
            (results[current].rejected || results[current].bodyMissing)
        ? _autoPick(results)
        : -1;
    state = state.copyWith(
      results: results,
      selected: next >= 0 ? next : current,
      bodyFetches: {...state.bodyFetches}..remove(candidate.ref),
    );
    if (next >= 0) await _ensureBody(results[next], generation);
  }

  // The first result that can be used: one with its lyrics, or a good match
  // whose lyrics are fetched next.
  int _autoPick(List<RankedCandidate> results) => results.indexWhere(
    (r) => r.selectable && !r.rejected && (r.hasBody || r.match.goodMatch),
  );

  void _setFetch(LyricsCandidate candidate, BodyFetchState fetch) {
    state = state.copyWith(
      selected: state.selected,
      bodyFetches: {...state.bodyFetches, candidate.ref: fetch},
    );
  }

  RankedCandidate _judge(LyricsCandidate candidate, LyricsBody? body) {
    final judged = body == null ? candidate : candidate.withBody(body);
    return RankedCandidate(
      judged,
      matchCandidate(
        target.query,
        judged,
        rejected: _rejected,
        rejectedHashes: _rejectedHashes,
      ),
      bodyMissing: body == null,
    );
  }
}
