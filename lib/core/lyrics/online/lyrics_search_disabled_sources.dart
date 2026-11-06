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
  Future<void> _loadRejected();
  Future<void>? get _rejectsLoad;
  set _rejectsLoad(Future<void>? load);

  /// Searches the disabled sources (only [ids] when given) that this search
  /// has not asked yet, with the current query. A newer search cancels them.
  Future<void> searchDisabled({Set<String>? ids}) async {
    final generation = _generation;
    final query = state.query;
    if (query.trim().isEmpty || !_current(generation)) return;
    await (_rejectsLoad ??= _loadRejected());
    if (!_current(generation)) return;
    final todo = [
      for (final r in ref.read(disabledLyricsProvidersProvider))
        if ((ids == null || ids.contains(r.id)) &&
            !state.onDemand.contains(r.id))
          r,
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
