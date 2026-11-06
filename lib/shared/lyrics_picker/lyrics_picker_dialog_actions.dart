part of 'lyrics_picker_dialog.dart';

/// The state and actions of [LyricsPickerDialog] besides its build: the query
/// field, the source filter, the list scroll and what the filter, the Search
/// sources modal, Search on an off source and Retry do.
mixin _PickerActions on ConsumerState<LyricsPickerDialog> {
  late final _query = TextEditingController(
    text: lyricsSearchPrefill(widget.target),
  );

  String? _sourceFilter; // provider id filtered to; null: every source

  // Scroll position of the result list, reset when the list changes.
  final _listScroll = ScrollController();

  bool get _searchesOnOpen => widget.target.query.title != null;

  bool get _queryBlank => _query.text.trim().isEmpty;

  // Rebuilds when the field turns blank or filled: Search on an off source
  // needs a query.
  void _watchBlank() {
    var wasBlank = _queryBlank;
    _query.addListener(() {
      if (wasBlank == _queryBlank) return;
      wasBlank = _queryBlank;
      if (mounted) setState(() {});
    });
  }

  LyricsSearchController get _controller =>
      ref.read(lyricsSearchControllerProvider(widget.target).notifier);

  LyricsSearchState get _searchState =>
      ref.read(lyricsSearchControllerProvider(widget.target));

  void _resetListScroll() {
    if (_listScroll.hasClients) _listScroll.jumpTo(0);
  }

  /// A new query starts from every source again.
  void _startOver() {
    setState(() => _sourceFilter = null);
    _resetListScroll();
  }

  /// Filters the list to [id] (`null`: every source); a selection the filter
  /// hides moves to the first result that stays.
  void _filterBySource(String? id) {
    setState(() => _sourceFilter = id);
    _resetListScroll();
    final search = _searchState;
    final next = resultToSelectForFilter(search.results, search.selected, id);
    if (next != null) _controller.select(next);
  }

  Future<void> _openSources() async {
    final choice = await showLyricsPickerSourcesModal(
      context,
      container: ProviderScope.containerOf(context),
      target: widget.target,
      selected: _sourceFilter,
      query: _query,
      searchOff: _searchOff,
    );
    if (choice == null || !mounted) return;
    _filterBySource(choice.id);
  }

  void _search() {
    _startOver();
    _controller.search(_query.text);
  }

  /// Search on off sources [ids], for the text in the query field.
  Future<void> _searchOff(Set<String> ids) {
    if (_queryBlank) return Future.value();
    if (_query.text.trim() != _searchState.query) _startOver();
    return _controller.searchDisabledFor(_query.text, ids: ids);
  }

  /// Retry of the failed source [id]; a failure of an on source runs the
  /// whole search again, which starts over from every source.
  void _retry(String id) {
    if (!_searchState.onDemand.contains(id)) _startOver();
    _controller.retrySource(id);
  }
}
