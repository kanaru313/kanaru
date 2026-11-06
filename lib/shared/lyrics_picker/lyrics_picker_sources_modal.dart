import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../core/lyrics/online/lyrics_search_controller.dart';
import '../../core/lyrics/online/lyrics_source_names.dart';
import '../../core/lyrics/online/lyrics_target.dart';
import '../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../l10n/l10n.dart';
import '../lyrics_plugins/plugin_icon.dart';
import '../widgets/layered_modal/layered_modal_route.dart';
import '../widgets/selection_row.dart';
import 'lyrics_picker_result_sources.dart';
import 'lyrics_source_name_text.dart';

/// Opens the "Search sources" child modal over the picker: the source filter
/// ("All sources", each source that is on) and the off sources, which can be
/// searched one by one. Returns the chosen filter (`id` is `null` for every
/// source), or `null` when it was closed without a choice. The modal reads
/// the search of [target] through [container], so a row changes at once when
/// an off source is searched.
Future<({String? id})?> showLyricsPickerSourcesModal(
  BuildContext context, {
  required ProviderContainer container,
  required LyricsTarget target,
  required String? selected,
  required TextEditingController query,
  required Future<void> Function(Set<String> ids) searchOff,
}) => showLayeredModal<({String? id})>(
  context,
  semanticLabel: context.l10n.lyricsPickerSourcesTitle,
  builder: (_) => UncontrolledProviderScope(
    container: container,
    child: _SourcesModal(
      target: target,
      selected: selected,
      query: query,
      searchOff: searchOff,
    ),
  ),
);

class _SourcesModal extends ConsumerWidget {
  const _SourcesModal({
    required this.target,
    required this.selected,
    required this.query,
    required this.searchOff,
  });

  final LyricsTarget target;
  final String? selected;

  /// The picker's query field; off sources are searched for its text.
  final TextEditingController query;
  final Future<void> Function(Set<String> ids) searchOff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(lyricsSearchControllerProvider(target));
    final names = ref.watch(lyricsSourceNamesProvider);
    final entries = ref.watch(lyricsSourcesProvider);
    final counts = {
      for (final s in lyricsResultSources(state.results)) s.id: s.count,
    };
    final filter = effectiveSourceFilter(
      selected,
      lyricsResultSources(state.results),
    );
    final total = counts.values.fold<int>(0, (n, c) => n + c);
    final off = ref.watch(disabledLyricsProvidersProvider);

    void choose(String? id) => Navigator.of(context).pop((id: id));
    String nameOf(String id) => lyricsSourceNameText(l10n, names, id);
    Widget icon(String id) => PluginIcon(
      record: entries.where((e) => e.id == id).firstOrNull?.record,
      size: 28,
      letterOf: nameOf(id),
    );

    return LayeredModalBody(
      header: LayeredModalTopBar(
        title: l10n.lyricsPickerSourcesTitle,
        onClose: () => Navigator.of(context).pop(),
      ),
      children: [
        SelectionRow(
          title: l10n.lyricsPickerSourceMenuAll,
          trailing: Text('$total'),
          selected: filter == null,
          onTap: () => choose(null),
        ),
        for (final r in ref.watch(lyricsProvidersProvider))
          SelectionRow(
            title: nameOf(r.id),
            leading: icon(r.id),
            trailing: Text('${counts[r.id] ?? 0}'),
            selected: filter == r.id,
            onTap: counts.containsKey(r.id) ? () => choose(r.id) : null,
          ),
        if (off.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 12, 24, 4),
            child: Text(
              l10n.lyricsPickerSourcesOff,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final r in off)
          if (state.onDemand.contains(r.id))
            SelectionRow(
              title: nameOf(r.id),
              subtitle: l10n.lyricsPickerSourceOff,
              leading: icon(r.id),
              trailing: Text('${counts[r.id] ?? 0}'),
              selected: filter == r.id,
              onTap: counts.containsKey(r.id) ? () => choose(r.id) : null,
            )
          else
            // Searching needs a query: the row is off while the field is
            // blank, and a tap anywhere on it searches this source.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: query,
              builder: (context, value, _) {
                final search = value.text.trim().isEmpty
                    ? null
                    : () => searchOff({r.id});
                return SelectionRow(
                  title: nameOf(r.id),
                  subtitle: r.hosts.join(', '),
                  leading: icon(r.id),
                  trailing: TextButton(
                    onPressed: search,
                    child: Text(l10n.lyricsPickerSearch),
                  ),
                  selected: false,
                  onTap: search,
                );
              },
            ),
      ],
    );
  }
}
