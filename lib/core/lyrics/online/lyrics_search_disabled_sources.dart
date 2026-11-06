part of 'lyrics_search_controller.dart';

/// The providers a search of [state] has asked: the enabled sources and the
/// disabled ones searched on demand, never every disabled source. Names,
/// hosts and the body fetch of a result are looked up in this list.
List<LyricsProviderRegistration> searchRegistrations({
  required List<LyricsProviderRegistration> enabled,
  required List<LyricsProviderRegistration> disabled,
  required LyricsSearchState state,
}) => [...enabled, ...disabled.where((r) => state.onDemand.contains(r.id))];

/// Asking disabled sources from the manual search, for
/// [LyricsSearchController]. Only an explicit call reaches them, and only
/// for the current search; settings stay as they are.
mixin _SearchDisabledSources on Notifier<LyricsSearchState> {
  int get _generation;
  Future<void> _searchOne(
    LyricsProviderRegistration registration,
    String text,
    int generation,
  );
  bool _current(int generation);
  Future<void> search(String text);
  Future<void> _loadRejected();
  Future<void>? get _rejectsLoad;
  set _rejectsLoad(Future<void>? load);

  // Not asked in this search yet, or asked and failed (asking again is the
  // retry of that source).
  bool _askable(String id) =>
      !state.onDemand.contains(id) ||
      state.byProvider[id]?.phase == ProviderSearchPhase.error;

  /// Searches the disabled sources [ids] for [text], the text the user has in
  /// the query field. A blank text does nothing. When it differs from the
  /// query last searched, the normal search of the enabled sources runs first
  /// (it drops the sources asked on request), so the answers always belong to
  /// the text on screen.
  Future<void> searchDisabledFor(String text, {Set<String>? ids}) async {
    final query = text.trim();
    if (query.isEmpty) return;
    if (query != state.query) await search(query);
    // A newer search may have replaced this one while it waited: never ask
    // the disabled sources with a query the user did not submit.
    if (state.query != query) return;
    await searchDisabled(ids: ids);
  }

  /// Searches the disabled sources (only [ids] when given) that this search
  /// has not asked yet or that failed, with the current query. A newer search
  /// cancels them.
  Future<void> searchDisabled({Set<String>? ids}) async {
    final generation = _generation;
    final query = state.query;
    if (query.trim().isEmpty || !_current(generation)) return;
    await (_rejectsLoad ??= _loadRejected());
    if (!_current(generation)) return;
    final todo = [
      for (final r in ref.read(disabledLyricsProvidersProvider))
        if ((ids == null || ids.contains(r.id)) && _askable(r.id)) r,
    ];
    if (todo.isEmpty) return;
    state = state.copyWith(
      selected: state.selected,
      onDemand: {...state.onDemand, for (final r in todo) r.id},
      byProvider: {
        ...state.byProvider,
        for (final r in todo)
          r.id: const ProviderSearchState(ProviderSearchPhase.searching),
      },
    );
    await Future.wait([for (final r in todo) _searchOne(r, query, generation)]);
  }
}
