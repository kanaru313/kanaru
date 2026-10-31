import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// The source filter above the results: "All sources (n)" and one chip per
/// source that returned results. [sources] are provider ids in the order of
/// the results; [selected] is the filtered id, or `null` for all. It is for
/// two or more sources only: with one there is nothing to filter, so it
/// draws nothing.
class LyricsPickerSourceChips extends StatelessWidget {
  const LyricsPickerSourceChips({
    super.key,
    required this.sources,
    required this.providerNames,
    required this.selected,
    required this.onSelected,
  });

  final List<String> sources;

  /// Display name by provider id.
  final Map<String, String> providerNames;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (sources.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: Text(context.l10n.lyricsPickerAllSources(sources.length)),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
            for (final id in sources)
              Tooltip(
                message: providerNames[id] ?? id,
                child: ChoiceChip(
                  // A long plugin name shortens instead of widening the row.
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      providerNames[id] ?? id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  selected: selected == id,
                  onSelected: (_) => onSelected(id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
