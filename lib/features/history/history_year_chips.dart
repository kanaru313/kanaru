import 'package:material_ui/material_ui.dart';

/// One chip per year with plays, newest first; the [selected] one is on.
class HistoryYearChips extends StatelessWidget {
  const HistoryYearChips({
    super.key,
    required this.years,
    required this.selected,
    required this.onSelected,
  });

  final List<int> years;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // Start-aligned under the toolbar; a parent Column would center it.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // The toolbar above already pads its bottom edge.
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
        child: Row(
          children: [
            for (final year in years)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$year'),
                  // No 48px tap target padding: it reads as a gap under the
                  // toolbar.
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  selected: year == selected,
                  onSelected: (_) => onSelected(year),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
