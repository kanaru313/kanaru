import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'history_days.dart';
import 'history_range_span.dart';

/// Title block of the range dialog: a small caption and, large, the picked
/// days ("Sep 27 – Oct 26, 2026"). Days not picked yet show as dim
/// placeholders.
class HistoryRangeDialogHeader extends StatelessWidget {
  const HistoryRangeDialogHeader({
    super.key,
    required this.start,
    required this.end,
  });

  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final dim = theme.textTheme.headlineSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
    );
    final first = start;
    final last = end;
    final Widget title;
    if (first != null && last != null) {
      title = Text(
        historySpanText(locale, first, last),
        style: theme.textTheme.headlineSmall,
      );
    } else {
      final full = DateFormat.yMMMd(locale);
      title = Text.rich(
        TextSpan(
          style: theme.textTheme.headlineSmall,
          children: [
            first == null
                ? TextSpan(text: l10n.historyRangeStartPlaceholder, style: dim)
                : TextSpan(text: full.format(first)),
            const TextSpan(text: ' – '),
            TextSpan(text: l10n.historyRangeEndPlaceholder, style: dim),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.historyRangeDialogTitle,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        title,
      ],
    );
  }
}

/// The month in view with arrows to the months around it; an arrow is off
/// when there is no month to go to.
class HistoryMonthBar extends StatelessWidget {
  const HistoryMonthBar({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(AppIcons.chevronLeft),
          tooltip: loc.previousMonthTooltip,
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            DateFormat.yMMMM(Localizations.localeOf(context).toString())
                .format(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(AppIcons.chevronRight),
          tooltip: loc.nextMonthTooltip,
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// What to do next, or how many days are picked.
String historyRangeHint(BuildContext context, DateTime? start, DateTime? end) {
  final l10n = context.l10n;
  final first = start;
  final last = end;
  if (first == null) return l10n.historyRangePickStart;
  if (last == null) return l10n.historyRangePickEnd;
  return l10n.historyRangeDays(daysBetween(first, last) + 1);
}

/// Hint on the left, Cancel and Save on the right. [onSave] null turns Save
/// off.
class HistoryRangeFooter extends StatelessWidget {
  const HistoryRangeFooter({
    super.key,
    required this.hint,
    required this.onSave,
  });

  final String hint;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = MaterialLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            hint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.cancelButtonLabel),
        ),
        TextButton(onPressed: onSave, child: Text(loc.saveButtonLabel)),
      ],
    );
  }
}

/// Runs [save] on Enter, unless a button has the focus: then Enter belongs to
/// that button (Cancel, a month arrow), which handles it further up.
KeyEventResult saveOnEnter(
  BuildContext context,
  KeyEvent event,
  VoidCallback save,
) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  final key = event.logicalKey;
  if (key != LogicalKeyboardKey.enter &&
      key != LogicalKeyboardKey.numpadEnter) {
    return KeyEventResult.ignored;
  }
  var onButton = false;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
    if (e.widget is ButtonStyleButton) {
      onButton = true;
      return false;
    }
    return true;
  });
  if (onButton) return KeyEventResult.ignored;
  save();
  return KeyEventResult.handled;
}
