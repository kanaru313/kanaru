import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../database/library_startup.dart';
import '../../database/online_lyrics_queries.dart';
import 'lyrics_candidate_checks.dart';
import 'lyrics_fetch_exception.dart';
import 'lyrics_http_retry.dart' show LyricsRequestAbandoned;
import 'lyrics_match.dart';
import 'lyrics_provider.dart';
import 'lyrics_provider_registry.dart';
import 'run_online_lyrics_lookup.dart' show maxLookupFetches;
import 'lyrics_search_state.dart';
import 'lyrics_source_names.dart';
import 'lyrics_target.dart';
import 'online_lyrics_http_factory.dart';

export 'lyrics_search_state.dart';

final _log = Logger('lyrics_search');

/// The manual search of the Choose lyrics dialog for one song. Every
/// provider is asked through [OnlineLyricsHttpFactory.forManual], so a
/// provider without the user's consent shows an error and sends nothing. A
/// sent request cannot be aborted; a newer search stops the older one from
/// sending anything more (its requests are abandoned) and the answers that
/// still arrive are dropped. Every answer of a provider goes through the host
/// checks before it is ranked.
///
/// A result that came without its lyrics (a two-step source) can be
/// selected; selecting it fetches them, and [LyricsSearchState.bodyFetches]
/// tells whether that is running or failed.
class LyricsSearchController extends Notifier<LyricsSearchState> {
  LyricsSearchController(this.target);

  final LyricsTarget target;

  int _generation = 0;
  final _raw = <String, List<LyricsCandidate>>{};
  Set<({String providerId, String remoteId})> _rejected = const {};
  Set<String> _rejectedHashes = const {};

  // Results whose lyrics were fetched and the provider has none.
  final _bodyMissing = <({String providerId, String remoteId})>{};

  // The selection was made by the search, not by a click.
  bool _autoSelected = false;

  // Automatic body fetches made for the current search; capped so a list of
  // results without lyrics does not turn into a run of requests.
  int _autoFetches = 0;

  @override
  LyricsSearchState build() =>
      LyricsSearchState(query: lyricsSearchPrefill(target));

  /// Searches every enabled provider for [text], once the sources are
  /// loaded. A blank text does nothing.
  Future<void> search(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;
    final generation = ++_generation;
    if (!ref.read(lyricsSourcesLoadedProvider)) {
      await whenLyricsSourcesLoaded(ref);
      if (!_current(generation)) return;
    }
    final registrations = ref.read(lyricsProvidersProvider);
    _raw.clear();
    _bodyMissing.clear();
    _autoSelected = false;
    _autoFetches = 0;
    state = LyricsSearchState(
      query: query,
      byProvider: {
        for (final r in registrations)
          r.id: const ProviderSearchState(ProviderSearchPhase.searching),
      },
    );
    await _loadRejected();
    if (!_current(generation)) return;
    await Future.wait([
      for (final r in registrations) _searchOne(r, query, generation),
    ]);
  }

  /// Runs the current query again, e.g. after a failure.
  Future<void> retry() => search(state.query);

  /// Selects result [index]; out of range clears the selection. A selected
  /// result without its lyrics has them fetched (one fetch at a time per
  /// result; selecting a failed one tries again); the future completes when
  /// that is done.
  Future<void> select(int? index) async {
    final inRange = index != null && index >= 0 && index < state.results.length;
    _autoSelected = false;
    state = state.copyWith(selected: inRange ? index : null);
    if (inRange) await _ensureBody(state.results[index], _generation);
  }

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

  bool _current(int generation) => ref.mounted && generation == _generation;

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

  Future<void> _searchOne(
    LyricsProviderRegistration registration,
    String text,
    int generation,
  ) async {
    ProviderSearchState outcome;
    List<LyricsCandidate> found = const [];
    try {
      final http = ref
          .read(onlineLyricsHttpFactoryProvider)
          .forManual(registration, abandoned: () => !_current(generation));
      found = checkCandidates(
        await registration.provider.search(LyricsQuery(text: text), http),
        providerId: registration.id,
      );
      outcome = const ProviderSearchState(ProviderSearchPhase.done);
    } on LyricsRequestAbandoned {
      // A newer search replaced this one before the request went out.
      return;
    } on LyricsFetchException catch (e) {
      outcome = ProviderSearchState(ProviderSearchPhase.error, e.kind);
    } on Object catch (e) {
      _log.warning('search failed: ${e.runtimeType}');
      outcome = const ProviderSearchState(ProviderSearchPhase.error);
    }
    if (!_current(generation)) return;
    _raw[registration.id] = found;
    final previous = state.selection?.candidate.ref;
    final results = _rank();
    var selected = previous == null
        ? -1
        : results.indexWhere((r) => r.candidate.ref == previous);
    final kept = selected >= 0;
    if (!kept) {
      selected = _autoPick(results);
      _autoSelected = selected >= 0;
    }
    state = state.copyWith(
      byProvider: {...state.byProvider, registration.id: outcome},
      results: results,
      selected: selected < 0 ? null : selected,
    );
    if (!kept && selected >= 0) {
      await _ensureBody(results[selected], generation);
    }
  }

  List<RankedCandidate> _rank() {
    final ranked = rankCandidates(
      target.query,
      [for (final list in _raw.values) ...list],
      rejected: _rejected,
      rejectedHashes: _rejectedHashes,
      keepRejected: true,
    );
    return [
      for (final m in ranked.take(maxSearchResults))
        RankedCandidate(
          m.candidate,
          m,
          bodyMissing: _bodyMissing.contains(m.candidate.ref),
        ),
    ];
  }
}

final lyricsSearchControllerProvider = NotifierProvider.autoDispose
    .family<LyricsSearchController, LyricsSearchState, LyricsTarget>(
      LyricsSearchController.new,
    );
