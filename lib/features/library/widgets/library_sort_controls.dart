import 'package:material_ui/material_ui.dart';

import '../../../core/settings/library_sort.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';

/// Sort controls of a library screen, for the page title row: a
/// "`field` ▾" menu of radio entries and an arrow button that flips the
/// direction. The arrow shows the current direction; a tap switches it.
class LibrarySortControls<F extends Enum> extends StatelessWidget {
  const LibrarySortControls({
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
    final order =
        '${l10n.sortOrder} '
        '${choice.descending ? l10n.sortDescending : l10n.sortAscending}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SortFieldMenu<F>(
          label: l10n.sortBy,
          selected: choice.field,
          options: {for (final field in fields) field: label(l10n, field)},
          onSelected: (field) => onChanged(choice.copyWith(field: field)),
        ),
        IconButton(
          tooltip: order,
          icon: Icon(
            choice.descending
                ? AppIcons.sortDescending
                : AppIcons.sortAscending,
          ),
          onPressed: () =>
              onChanged(choice.copyWith(descending: !choice.descending)),
        ),
      ],
    );
  }
}

/// A "value ▾" text button opening a menu with one radio entry per field.
/// Focus goes back to the button when the menu closes.
class _SortFieldMenu<T> extends StatefulWidget {
  const _SortFieldMenu({
    required this.label,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  /// Read out by screen readers; not shown.
  final String label;
  final T selected;

  /// The choices in menu order, with their text.
  final Map<T, String> options;
  final ValueChanged<T> onSelected;

  @override
  State<_SortFieldMenu<T>> createState() => _SortFieldMenuState<T>();
}

class _SortFieldMenuState<T> extends State<_SortFieldMenu<T>> {
  final _buttonFocus = FocusNode(debugLabel: 'Sort menu button');

  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.options[widget.selected] ?? '';

    return MenuAnchor(
      childFocusNode: _buttonFocus,
      menuChildren: [
        for (final MapEntry(key: value, value: text) in widget.options.entries)
          RadioMenuButton<T>(
            value: value,
            groupValue: widget.selected,
            onChanged: (value) {
              if (value != null) widget.onSelected(value);
            },
            child: Text(text),
          ),
      ],
      builder: (context, controller, child) => TextButton(
        focusNode: _buttonFocus,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The label is read with the value, on the button's own node.
            Text(value, semanticsLabel: '${widget.label} $value'),
            const Icon(AppIcons.expandMore, size: 18),
          ],
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
