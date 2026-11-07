import 'package:material_ui/material_ui.dart';

import '../../core/database/text_keys.dart';
import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import 'in_page_no_match.dart';
import 'layered_modal/layered_modal_route.dart';
import 'selection_row.dart';

/// Item count above which [showSelectionPicker] shows a search box.
const int _searchThreshold = 8;

/// One entry in a [showSelectionPicker] list.
class SelectionPickerItem<T> {
  const SelectionPickerItem({
    required this.value,
    required this.name,
    this.description,
    this.leading,
    this.badge,
  });

  /// Value returned by the picker when this entry is chosen.
  final T value;

  /// Row title; also matched by the search box.
  final String name;

  /// Optional second line under [name]; also matched by the search box.
  final String? description;

  /// Optional widget before the title.
  final Widget? leading;

  /// Optional tag after the row text (see [SelectionRow.badge]).
  final Widget? badge;
}

/// Opens a layered selection modal with [title], a close button, and one
/// [SelectionRow] per entry in [items].
///
/// When [items] has more than 8 entries, an
/// autofocused search box filters [SelectionPickerItem.name] and
/// [SelectionPickerItem.description] ignoring case and accents via [sortKey].
///
/// Tapping or activating a row closes the picker and returns its value; the
/// close button, scrim, or Esc returns `null`.
///
/// [footer] is the last child of the scrolling list (after the rows and
/// before [hint]), not pinned below it. [hint] is a small muted note at the
/// end of the list; it is hidden while a search matches nothing, the [footer]
/// stays. [header] is an optional widget between the title bar and the
/// search box (for example scope segments); null leaves the layout unchanged.
Future<T?> showSelectionPicker<T>(
  BuildContext context, {
  required String title,
  required List<SelectionPickerItem<T>> items,
  T? selected,
  Widget? footer,
  Widget? header,
  String? hint,
  String? semanticLabel,
}) {
  return showLayeredModal<T>(
    context,
    semanticLabel: semanticLabel ?? title,
    builder: (_) => _SelectionPickerContent<T>(
      title: title,
      items: items,
      selected: selected,
      footer: footer,
      header: header,
      hint: hint,
    ),
  );
}

class _SelectionPickerContent<T> extends StatefulWidget {
  const _SelectionPickerContent({
    required this.title,
    required this.items,
    required this.selected,
    required this.footer,
    required this.header,
    required this.hint,
  });

  final String title;
  final List<SelectionPickerItem<T>> items;
  final T? selected;
  final Widget? footer;
  final Widget? header;
  final String? hint;

  @override
  State<_SelectionPickerContent<T>> createState() =>
      _SelectionPickerContentState<T>();
}

class _SelectionPickerContentState<T>
    extends State<_SelectionPickerContent<T>> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<SelectionPickerItem<T>> _filteredItems() {
    final key = sortKey(_query);
    if (key.isEmpty) return widget.items;
    return [
      for (final item in widget.items)
        if (_matches(item, key)) item,
    ];
  }

  bool _matches(SelectionPickerItem<T> item, String queryKey) {
    if (sortKey(item.name).contains(queryKey)) return true;
    final desc = item.description;
    return desc != null && sortKey(desc).contains(queryKey);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final showSearch = widget.items.length > _searchThreshold;
    final filtered = _filteredItems();
    final footer = widget.footer;
    final header = widget.header;
    final hint = widget.hint;
    final trimmedQuery = _query.trim();

    return LayeredModalBody(
      header: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayeredModalTopBar(
            title: widget.title,
            onClose: () => Navigator.of(context).pop(),
          ),
          ?header,
          if (showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: colors.surfaceContainer,
                  hintText: l10n.selectionPickerSearchHint(widget.items.length),
                  prefixIcon: const Icon(AppIcons.search, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(AppIcons.close, size: 18),
                          tooltip: l10n.inPageSearchClear,
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
        ],
      ),
      children: [
        if (filtered.isEmpty)
          InPageNoMatch(
            query: trimmedQuery,
            message: l10n.selectionPickerNoMatch(trimmedQuery),
          )
        else
          for (final item in filtered)
            SelectionRow(
              title: item.name,
              subtitle: item.description,
              leading: item.leading,
              badge: item.badge,
              selected: item.value == widget.selected,
              onTap: () => Navigator.of(context).pop(item.value),
            ),
        ?footer,
        if (hint != null && hint.isNotEmpty && filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.outline),
            ),
          ),
      ],
    );
  }
}
