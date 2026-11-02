import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_languages.dart';
import '../../core/lyrics/plugins/repo/lyrics_plugin_repos_provider.dart';
import '../../l10n/l10n.dart';
import 'plugin_store_filter_labels.dart';

/// Authors from which on the author group gets a search field.
const authorSearchMinValues = 4;

/// One group of the filter modal: its title, an "All" chip that clears the
/// group, and one chip per value with its count. The author group of
/// [authorSearchMinValues] or more values has a search field that narrows
/// the chips.
class PluginStoreFilterGroup extends StatefulWidget {
  const PluginStoreFilterGroup({
    super.key,
    required this.group,
    required this.onToggle,
    required this.onClear,
  });

  final StoreFacetGroup group;
  final void Function(String key) onToggle;
  final VoidCallback onClear;

  @override
  State<PluginStoreFilterGroup> createState() => _PluginStoreFilterGroupState();
}

class _PluginStoreFilterGroupState extends State<PluginStoreFilterGroup> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final group = widget.group;
    final entries = [
      for (final v in group.values)
        (value: v, label: storeFacetValueLabel(l10n, group.facet, v)),
    ];
    if (group.facet == StoreFacet.language) {
      // Global first, then by the name the user reads.
      entries.sort((a, b) {
        final ga = a.value.key == pluginLanguagesGlobal;
        final gb = b.value.key == pluginLanguagesGlobal;
        if (ga != gb) return ga ? -1 : 1;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
    }
    final searchable =
        group.facet == StoreFacet.author &&
        group.values.length >= authorSearchMinValues;
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final e in entries)
        if (!searchable ||
            query.isEmpty ||
            e.label.toLowerCase().contains(query))
          e,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              storeFacetTitle(l10n, group.facet),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (searchable)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: l10n.lyricsStoreFilterAuthorSearch,
                  isDense: true,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(l10n.lyricsStoreChipAll),
                selected: group.selected.isEmpty,
                onSelected: (_) => widget.onClear(),
              ),
              for (final e in shown)
                FilterChip(
                  label: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: e.label),
                        const TextSpan(text: '  '),
                        TextSpan(
                          text: '${e.value.count}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  selected: e.value.selected,
                  onSelected: (_) => widget.onToggle(e.value.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
