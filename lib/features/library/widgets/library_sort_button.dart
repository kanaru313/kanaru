import 'package:material_ui/material_ui.dart';

import '../../../core/settings/library_sort.dart';
import '../../../l10n/l10n.dart';

/// "Sort by" menu of a library screen: one radio entry per field, then
/// ascending and descending. Shows the current field and direction; focus
/// goes back to the button when the menu closes.
class LibrarySortButton<F extends Enum> extends StatefulWidget {
  const LibrarySortButton({
    super.key,
    required this.choice,
    required this.fields,
    required this.label,
    required this.onChanged,
  });

  final SortChoice<F> choice;
  final List<F> fields;
  final String Function(AppLocalizations l10n, F field) label;
  final ValueChanged<SortChoice<F>> onChanged;

  @override
  State<LibrarySortButton<F>> createState() => _LibrarySortButtonState<F>();
}

class _LibrarySortButtonState<F extends Enum>
    extends State<LibrarySortButton<F>> {
  final _buttonFocus = FocusNode(debugLabel: 'Sort button');

  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final choice = widget.choice;

    return MenuAnchor(
      childFocusNode: _buttonFocus,
      menuChildren: [
        for (final field in widget.fields)
          RadioMenuButton<F>(
            value: field,
            groupValue: choice.field,
            onChanged: (field) =>
                widget.onChanged(choice.copyWith(field: field)),
            child: Text(widget.label(l10n, field)),
          ),
        const Divider(),
        for (final descending in const [false, true])
          RadioMenuButton<bool>(
            value: descending,
            groupValue: choice.descending,
            onChanged: (descending) =>
                widget.onChanged(choice.copyWith(descending: descending)),
            child: Text(descending ? l10n.sortDescending : l10n.sortAscending),
          ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: l10n.sortTooltip,
        child: TextButton.icon(
          focusNode: _buttonFocus,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: Icon(
            choice.descending ? Icons.arrow_downward : Icons.arrow_upward,
          ),
          label: Text(widget.label(l10n, choice.field)),
        ),
      ),
    );
  }
}

/// Labels of the sort fields, shared by the screens and tests.
String songSortLabel(AppLocalizations l10n, SongSortField field) =>
    switch (field) {
      SongSortField.title => l10n.sortTitle,
      SongSortField.artist => l10n.sortArtist,
      SongSortField.album => l10n.sortAlbum,
      SongSortField.year => l10n.sortYear,
      SongSortField.dateAdded => l10n.sortDateAdded,
      SongSortField.duration => l10n.sortDuration,
    };

String albumSortLabel(AppLocalizations l10n, AlbumSortField field) =>
    switch (field) {
      AlbumSortField.title => l10n.sortTitle,
      AlbumSortField.artist => l10n.sortArtist,
      AlbumSortField.year => l10n.sortYear,
      AlbumSortField.dateAdded => l10n.sortDateAdded,
    };

String artistSortLabel(AppLocalizations l10n, ArtistSortField field) =>
    switch (field) {
      ArtistSortField.name => l10n.sortName,
      ArtistSortField.songCount => l10n.sortSongCount,
      ArtistSortField.albumCount => l10n.sortAlbumCount,
    };
