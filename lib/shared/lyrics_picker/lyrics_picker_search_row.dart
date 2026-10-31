import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'lyrics_picker_source_menu.dart';

/// The query row of the Choose lyrics dialog: the source filter chip, the
/// query field and Search. The chip has a fixed width, so the field stays put
/// whatever the filter reads.
class LyricsPickerSearchRow extends StatelessWidget {
  const LyricsPickerSearchRow({
    super.key,
    required this.query,
    required this.sources,
    required this.providerNames,
    required this.sourceFilter,
    required this.onSourceFilter,
    required this.onSearch,
  });

  final TextEditingController query;
  final List<({String id, int count})> sources;
  final Map<String, String> providerNames;
  final String? sourceFilter;
  final ValueChanged<String?> onSourceFilter;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        LyricsPickerSourceMenu(
          sources: sources,
          providerNames: providerNames,
          selected: sourceFilter,
          onSelected: onSourceFilter,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: l10n.lyricsPickerQueryHint,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Search stays off while the field is blank.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: query,
          builder: (context, value, _) => FilledButton.tonal(
            onPressed: value.text.trim().isEmpty ? null : onSearch,
            child: Text(l10n.lyricsPickerSearch),
          ),
        ),
      ],
    );
  }
}
