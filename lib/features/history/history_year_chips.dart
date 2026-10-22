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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Row(
        children: [
          for (final year in years)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$year'),
                selected: year == selected,
                onSelected: (_) => onSelected(year),
              ),
            ),
        ],
      ),
    );
  }
}
