import 'package:material_ui/material_ui.dart';

import '../../../core/settings/library_sort.dart';
import '../../../l10n/l10n.dart';

/// "Sort by" menu of a library screen: one entry per field, then ascending
/// and descending. Shows the current field and direction.
class LibrarySortButton<F extends Enum> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget check(bool selected) => selected
        ? const Icon(Icons.check)
        : const SizedBox.square(dimension: 24);

    return MenuAnchor(
      menuChildren: [
        for (final field in fields)
          MenuItemButton(
            leadingIcon: check(field == choice.field),
            onPressed: () => onChanged(choice.copyWith(field: field)),
            child: Text(label(l10n, field)),
          ),
        const Divider(),
        MenuItemButton(
          leadingIcon: check(!choice.descending),
          onPressed: () => onChanged(choice.copyWith(descending: false)),
          child: Text(l10n.sortAscending),
        ),
        MenuItemButton(
          leadingIcon: check(choice.descending),
          onPressed: () => onChanged(choice.copyWith(descending: true)),
          child: Text(l10n.sortDescending),
        ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: l10n.sortTooltip,
        child: TextButton.icon(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: Icon(
            choice.descending ? Icons.arrow_downward : Icons.arrow_upward,
          ),
          label: Text(label(l10n, choice.field)),
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
