import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/search/search_fields.dart';
import '../../core/search/search_prefs_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'search_request_provider.dart';

/// The name of [field] in the picker.
String searchFieldLabel(AppLocalizations l10n, SearchField field) =>
    switch (field) {
      SearchField.title => l10n.searchFieldTitle,
      SearchField.artist => l10n.searchFieldArtist,
      SearchField.album => l10n.searchFieldAlbum,
      SearchField.albumArtist => l10n.searchFieldAlbumArtist,
      SearchField.genre => l10n.searchFieldGenre,
      SearchField.fileName => l10n.searchFieldFileName,
      SearchField.comment => l10n.searchFieldComment,
    };

String _presetLabel(AppLocalizations l10n, SearchFieldPreset preset) =>
    switch (preset) {
      SearchFieldPreset.all => l10n.searchPresetAll,
      SearchFieldPreset.titleOnly => l10n.searchPresetTitleOnly,
    };

/// The preset whose fields are exactly [fields], if any.
SearchFieldPreset? _presetOf(Set<SearchField> fields) {
  for (final preset in SearchFieldPreset.values) {
    if (sameSearchFields(preset.fields, fields)) return preset;
  }
  return null;
}

/// A menu button for the search page: two presets and a checkbox per field.
/// The last chosen field cannot be turned off. A dot on the button shows that
/// the fields differ from the default. The choice is saved with the search
/// prefs.
class SearchFieldPicker extends ConsumerStatefulWidget {
  const SearchFieldPicker({super.key});

  @override
  ConsumerState<SearchFieldPicker> createState() => _SearchFieldPickerState();
}

class _SearchFieldPickerState extends ConsumerState<SearchFieldPicker> {
  final _buttonFocus = FocusNode(debugLabel: 'Search fields button');

  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  void _set(Set<SearchField> fields) {
    // Saved in the background; the state changes at once.
    ref.read(searchPrefsProvider.notifier).setFields(fields);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fields = ref.watch(searchFieldsProvider);
    final filtered = !isDefaultSearchFields(fields);
    final label = filtered
        ? l10n.searchFieldsFiltered
        : l10n.searchFieldsButton;
    final current = _presetOf(fields);
    final compact = PageScaffold.compactActionsOf(context);
    final icon = Badge(
      smallSize: 8,
      isLabelVisible: filtered,
      child: const Icon(AppIcons.searchFields),
    );

    return MenuAnchor(
      childFocusNode: _buttonFocus,
      menuChildren: [
        for (final preset in SearchFieldPreset.values)
          RadioMenuButton<SearchFieldPreset>(
            value: preset,
            groupValue: current,
            onChanged: (_) => _set(preset.fields),
            child: Text(_presetLabel(l10n, preset)),
          ),
        const Divider(height: 1),
        for (final field in SearchField.values)
          CheckboxMenuButton(
            value: fields.contains(field),
            closeOnActivate: false,
            // The last field stays on: a search needs somewhere to look.
            onChanged: fields.contains(field) && fields.length == 1
                ? null
                : (on) => _set({
                    for (final f in SearchField.values)
                      if (f == field ? on ?? false : fields.contains(f)) f,
                  }),
            child: Text(searchFieldLabel(l10n, field)),
          ),
      ],
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        return compact
            ? IconButton(
                focusNode: _buttonFocus,
                tooltip: label,
                icon: icon,
                onPressed: toggle,
              )
            : TextButton.icon(
                focusNode: _buttonFocus,
                icon: icon,
                label: Text(label),
                onPressed: toggle,
              );
      },
    );
  }
}
