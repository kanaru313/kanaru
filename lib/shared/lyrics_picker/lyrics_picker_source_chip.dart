import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../widgets/marquee_text.dart';
import 'lyrics_picker_result_sources.dart';

/// Width of the chip, fixed so the query field beside it never moves.
const double lyricsPickerSourceChipWidth = 200;

/// The source filter of the Choose lyrics dialog: a fixed-width chip that
/// opens the "Search sources" modal through [onPressed]. It reads "All
/// sources ({count})" (count of sources with results), or the name of the
/// filtered source on a tinted fill. Always enabled, also with one source or
/// none, because the modal is where off sources are searched. [sources] are
/// provider ids with their result counts; [selected] is the filtered id.
class LyricsPickerSourceChip extends StatefulWidget {
  const LyricsPickerSourceChip({
    super.key,
    required this.sources,
    required this.providerNames,
    required this.selected,
    required this.onPressed,
  });

  final List<({String id, int count})> sources;

  /// Display name by provider id.
  final Map<String, String> providerNames;
  final String? selected;
  final VoidCallback onPressed;

  @override
  State<LyricsPickerSourceChip> createState() => _LyricsPickerSourceChipState();
}

class _LyricsPickerSourceChipState extends State<LyricsPickerSourceChip> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final sources = widget.sources;
    final filter = effectiveSourceFilter(widget.selected, sources);
    final filterName = filter == null
        ? null
        : widget.providerNames[filter] ?? filter;
    final label =
        filterName ??
        (sources.length >= 2
            ? l10n.lyricsPickerAllSources(sources.length)
            : l10n.lyricsPickerSourceMenuAll);
    final filtered = filterName != null;
    return Semantics(
      label: l10n.lyricsPickerSourceFilterLabel(label),
      button: true,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: Tooltip(
        // Shows the full name of a filtered source.
        message: filtered ? filterName : '',
        child: SizedBox(
          width: lyricsPickerSourceChipWidth,
          // At least as tall as the dense field; grows with the text scale.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: OutlinedButton(
              onPressed: widget.onPressed,
              onHover: (h) => setState(() => _hovered = h),
              onFocusChange: (f) => setState(() => _focused = f),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.only(left: 12, right: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: filtered ? scheme.secondaryContainer : null,
                side: filtered ? BorderSide.none : null,
                alignment: Alignment.centerLeft,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MarqueeText(
                      text: label,
                      active: _hovered || _focused,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: filtered ? scheme.onSecondaryContainer : null,
                      ),
                    ),
                  ),
                  Icon(
                    AppIcons.dropDown,
                    color: filtered ? scheme.onSecondaryContainer : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
