import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/album_artist_label.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/in_page_filter.dart';
import '../../../shared/in_page_filter_host.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/in_page_no_match.dart';
import '../../../shared/widgets/in_page_search_field.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../widgets/library_sort_controls.dart';
import 'album_list_view.dart';
import 'album_sort.dart';
import 'albums_view_toggle.dart';
import 'album_grid.dart';

/// A full list of [albums] that belong to someone ([ownerName]): title with
/// "owner · N albums", a filter on what the tiles show, a sort kept only
/// while the page lives, and the grid or list of the Albums tab. Tapping an
/// album opens [albumLocation] of it. Give it a key that changes with the
/// owner, so a new owner starts with a fresh sort and filter.
class AlbumCollectionScreen extends ConsumerStatefulWidget {
  const AlbumCollectionScreen({
    super.key,
    required this.title,
    required this.ownerName,
    required this.albums,
    required this.initialSort,
    required this.albumLocation,
    this.showTotals = true,
  });

  final String title;
  final String ownerName;
  final List<AlbumSummary> albums;
  final SortChoice<AlbumSortField> initialSort;

  /// Where the page of an album is, below this list.
  final String Function(AlbumKey key) albumLocation;

  /// False when the albums hold songs of other owners too, so the song count
  /// and length of a list row would not be the owner's (see
  /// [AlbumListView.showTotals]).
  final bool showTotals;

  @override
  ConsumerState<AlbumCollectionScreen> createState() =>
      _AlbumCollectionScreenState();
}

class _AlbumCollectionScreenState extends ConsumerState<AlbumCollectionScreen>
    with InPageFilterHost<AlbumCollectionScreen> {
  /// The filter dies with the page, so leaving it clears it.
  final _filter = InPageFilterController();
  late SortChoice<AlbumSortField> _sort = widget.initialSort;
  late List<AlbumSummary> _sorted = sortAlbums(widget.albums, _sort);
  late InPageFilterView<AlbumSummary> _view;
  AppLocalizations? _viewL10n;

  @override
  InPageFilterController get filterController => _filter;

  @override
  bool get filterAvailable => widget.albums.isNotEmpty;

  /// Filters on what a tile shows (title, album artist label), so "Various
  /// artists" finds a merged album. Rebuilt only when the language changes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = context.l10n;
    if (identical(l10n, _viewL10n)) return;
    _viewL10n = l10n;
    _view = InPageFilterView<AlbumSummary>(
      (a) => (
        title: a.title,
        artist: albumArtistLabel(
          l10n,
          artist: a.artist,
          variousArtists: a.variousArtists,
        ),
        album: null,
      ),
    );
  }

  /// A reload brings new lists: sorts them again with the sort the user
  /// chose, and keeps the filter text and scroll position.
  @override
  void didUpdateWidget(AlbumCollectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.albums, widget.albums)) return;
    _sorted = sortAlbums(widget.albums, _sort);
    if (widget.albums.isEmpty) _filter.close();
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _setSort(SortChoice<AlbumSortField> sort) => setState(() {
    _sort = sort;
    _sorted = sortAlbums(widget.albums, sort);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = ref.watch(settingsProvider.select((s) => s.albumsView));
    final total = widget.albums.length;
    return ListenableBuilder(
      listenable: _filter,
      builder: (context, _) {
        final terms = _filter.terms;
        // Matches best first, put back in the order of the sort.
        final shown = terms.isEmpty
            ? _sorted
            : [
                for (final i in [..._view.rank(_sorted, terms)]..sort())
                  _sorted[i],
              ];
        final count = l10n.artistsAlbumCount(total);
        return PageScaffold(
          title: widget.title,
          subtitle: l10n.albumsOwnerSummary(
            widget.ownerName,
            terms.isEmpty
                ? count
                : l10n.albumsShownOfTotal(shown.length, count),
          ),
          actions: [
            if (total > 0)
              // Inside the scaffold, so the width follows its header.
              Builder(
                builder: (context) => InPageSearchField(
                  controller: _filter,
                  hintText: l10n.albumsFilterHint,
                  width: PageScaffold.compactActionsOf(context) ? 200 : 280,
                ),
              ),
            const AlbumsViewToggle(),
            LibrarySortControls<AlbumSortField>(
              choice: _sort,
              fields: AlbumSortField.values,
              label: albumSortLabel,
              onChanged: _setSort,
            ),
          ],
          body: _body(l10n, view, shown),
        );
      },
    );
  }

  Widget _body(
    AppLocalizations l10n,
    AlbumsView view,
    List<AlbumSummary> shown,
  ) {
    if (widget.albums.isEmpty) {
      return EmptyState(
        icon: AppIcons.albumOutlined,
        title: l10n.albumsSectionEmpty,
      );
    }
    if (_filter.isFiltering && shown.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: InPageNoMatch(
          query: _filter.query,
          message: l10n.albumsFilterNoMatch(_filter.query),
        ),
      );
    }
    void open(AlbumSummary a) => context.go(widget.albumLocation(a.key));
    void queue(AlbumSummary a, QueueAction action) =>
        enqueueAlbum(ref, context, action, a.key, a.title);
    return switch (view) {
      AlbumsView.grid => AlbumGrid(
        albums: shown,
        onTap: open,
        onQueueAction: queue,
      ),
      AlbumsView.list => AlbumListView(
        albums: shown,
        showTotals: widget.showTotals,
        onTap: open,
        onQueueAction: queue,
      ),
    };
  }
}
