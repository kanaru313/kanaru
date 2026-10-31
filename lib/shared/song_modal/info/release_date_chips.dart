import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/track_details/release_date.dart';
import '../../../l10n/l10n.dart';

/// The chips next to a release date: the date written out as far as the tag
/// gave it (year; year and month; full date), then how long ago it was.
/// Empty for a date in the future. A year alone is not repeated when it is
/// all the field already says.
List<String> releaseDateChipLabels(
  AppLocalizations l10n,
  ReleaseDate date, {
  required DateTime now,
}) {
  final locale = l10n.localeName;
  final month = date.month;
  final day = date.day;
  final readable = month == null
      ? null
      : day == null
      ? DateFormat.yMMM(locale).format(DateTime(date.year, month))
      : DateFormat.yMMMd(locale).format(DateTime(date.year, month, day));
  final yearsAgo = now.year - date.year;
  return [?readable, if (yearsAgo >= 0) l10n.songInfoYearsAgo(yearsAgo)];
}

/// [labels] as small tonal chips on one wrapping line.
class ReleaseDateChips extends StatelessWidget {
  const ReleaseDateChips({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final label in labels)
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
