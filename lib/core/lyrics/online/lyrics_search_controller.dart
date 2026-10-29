import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../database/library_startup.dart';
import '../../database/online_lyrics_queries.dart';
import 'lyrics_fetch_exception.dart';
import 'lyrics_match.dart';
import 'lyrics_provider.dart';
import 'lyrics_provider_registry.dart';
import 'lyrics_search_state.dart';
import 'lyrics_target.dart';
import 'online_lyrics_http_factory.dart';

export 'lyrics_search_state.dart';

final _log = Logger('lyrics_search');

/// The manual search of the Choose lyrics dialog for one song. Every
/// provider is asked through [OnlineLyricsHttpFactory.forManual], so a
/// provider without the user's consent shows an error and sends nothing. A
/// sent request cannot be aborted; the answers of an older search are
/// dropped instead.
class LyricsSearchController extends Notifier<LyricsSearchState> {
  LyricsSearchController(this.target);

  final LyricsTarget target;

  int _generation = 0;
  final _raw = <String, List<LyricsCandidate>>{};
  Set<({String providerId, String remoteId})> _rejected = const {};
  Set<String> _rejectedHashes = const {};

  @override
  LyricsSearchState build() =>
      LyricsSearchState(query: lyricsSearchPrefill(target));

  /// Searches every provider for [text]. A blank text does nothing.
  Future<void> search(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;
    final generation = ++_generation;
    final registrations = ref.read(lyricsProvidersProvider);
    _raw.clear();
    state = LyricsSearchState(
      query: query,
      byProvider: {
        for (final r in registrations)
          r.id: const ProviderSearchState(ProviderSearchPhase.searching),
      },
    );
    final rejects = await _loadRejected();
    _rejected = rejects.ids;
    _rejectedHashes = rejects.hashes;
    if (!_current(generation)) return;
    await Future.wait([
      for (final r in registrations) _searchOne(r, query, generation),
    ]);
  }

  /// Runs the current query again, e.g. after a failure.
  Future<void> retry() => search(state.query);

  /// Selects result [index]; out of range clears the selection.
  void select(int? index) {
    final inRange = index != null && index >= 0 && index < state.results.length;
    state = state.copyWith(selected: inRange ? index : null);
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  Future<
    ({Set<({String providerId, String remoteId})> ids, Set<String> hashes})
  >
  _loadRejected() async {
    try {
      final matches = await ref
          .read(libraryDatabaseProvider)
          ?.rejectedMatches(target.cacheKey);
      return (
        ids: {
          for (final (providerId, remoteId)
              in matches?.ids ?? const <(String, String)>{})
            (providerId: providerId, remoteId: remoteId),
        },
        hashes: matches?.hashes ?? const <String>{},
      );
    } on Object catch (e) {
      _log.warning('could not read rejected lyrics: ${e.runtimeType}');
      return (
        ids: const <({String providerId, String remoteId})>{},
        hashes: const <String>{},
      );
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
          .forManual(registration);
      found = await registration.provider.search(LyricsQuery(text: text), http);
      outcome = const ProviderSearchState(ProviderSearchPhase.done);
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
        ? null
        : results.indexWhere((r) => r.candidate.ref == previous);
    if (selected == null || selected < 0) {
      selected = results.indexWhere((r) => r.selectable && !r.rejected);
    }
    state = state.copyWith(
      byProvider: {...state.byProvider, registration.id: outcome},
      results: results,
      selected: selected < 0 ? null : selected,
    );
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
        RankedCandidate(m.candidate, m),
    ];
  }
}

final lyricsSearchControllerProvider = NotifierProvider.autoDispose
    .family<LyricsSearchController, LyricsSearchState, LyricsTarget>(
      LyricsSearchController.new,
    );
