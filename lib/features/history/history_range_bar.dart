import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'history_days.dart';
import 'history_range.dart';
import 'most_played_limit.dart';

const double _navRowCenterReserve = 132;

/// What the range is called: "Today" for the current day, "All time", else
/// the first and last day in the medium date format. Also names the playlist
/// made from the list.
String historyRangeText(
  BuildContext context,
  HistoryRangeState state,
  DateTime now,
) {
  final l10n = context.l10n;
  final days = state.days(now);
  if (days == null) return l10n.historyRangeAll;
  if (state.preset == HistoryRangePreset.today && state.back == 0) {
    return l10n.historyRangeToday;
  }
  final dates = MaterialLocalizations.of(context);
  return l10n.historyRangeLabel(
    dates.formatMediumDate(days.start),
    dates.formatMediumDate(addDays(days.end, -1)),
  );
}

/// The range controls of the Most played page: a chip per preset and one for a
/// custom range, then a second row containing centered period navigation
/// (except for all time) and a right-aligned top limit dropdown.
class HistoryRangeBar extends StatelessWidget {
  const HistoryRangeBar({
    super.key,
    required this.state,
    required this.now,
    required this.canPickCustom,
    required this.topLimit,
    required this.onPreset,
    required this.onCustom,
    required this.onShift,
    required this.onTopLimit,
  });

  final HistoryRangeState state;
  final DateTime now;

  /// False while there is no play to pick a day among.
  final bool canPickCustom;
  final int topLimit;
  final ValueChanged<HistoryRangePreset> onPreset;
  final VoidCallback onCustom;

  /// Called with -1 for the previous period and 1 for the next.
  final ValueChanged<int> onShift;
  final ValueChanged<int> onTopLimit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      HistoryRangePreset.today: l10n.historyRangeToday,
      HistoryRangePreset.days7: l10n.historyRange7Days,
      HistoryRangePreset.days30: l10n.historyRange30Days,
      HistoryRangePreset.months6: l10n.historyRange6Months,
      HistoryRangePreset.year: l10n.historyRangeYear,
      HistoryRangePreset.all: l10n.historyRangeAll,
    };
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
          child: Row(
            children: [
              for (final e in labels.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: state.preset == e.key,
                    onSelected: (_) => onPreset(e.key),
                  ),
                ),
              ChoiceChip(
                label: Text(l10n.historyRangeCustom),
                selected: state.preset == HistoryRangePreset.custom,
                onSelected: canPickCustom ? (_) => onCustom() : null,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (state.preset != HistoryRangePreset.all)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _navRowCenterReserve,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(AppIcons.chevronLeft),
                        tooltip: l10n.historyRangePrevious,
                        onPressed: () => onShift(-1),
                      ),
                      Flexible(
                        child: Text(
                          historyRangeText(context, state, now),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(AppIcons.chevronRight),
                        tooltip: l10n.historyRangeNext,
                        onPressed:
                            state.canGoNext(now) ? () => onShift(1) : null,
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 32),
                  child: HistoryTopLimitDropdown(
                    limit: topLimit,
                    onChanged: onTopLimit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dropdown menu for selecting the active ranking limit in Most played.
class HistoryTopLimitDropdown extends StatelessWidget {
  const HistoryTopLimitDropdown({
    super.key,
    required this.limit,
    required this.onChanged,
  });

  final int limit;
  final ValueChanged<int> onChanged;

  static const _customAction = -1;
  static const _presets = [5, 10, 50, 100];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return PopupMenuButton<int>(
      padding: EdgeInsets.zero,
      tooltip: l10n.historyTopLimitOption(limit),
      borderRadius: BorderRadius.circular(8),
      onSelected: (value) {
        if (value == _customAction) {
          unawaited(_showCustomDialog(context, limit, onChanged));
        } else {
          onChanged(value);
        }
      },
      itemBuilder: (context) => [
        for (final preset in _presets)
          PopupMenuItem<int>(
            value: preset,
            child: Row(
              children: [
                if (preset == limit)
                  Icon(AppIcons.check, size: 18, color: primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(
                  l10n.historyTopLimitOption(preset),
                  style: preset == limit
                      ? TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primary,
                        )
                      : null,
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          value: _customAction,
          child: Row(
            children: [
              const SizedBox(width: 18),
              const SizedBox(width: 8),
              Text(l10n.historyTopCustomOption),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.historyTopLimitOption(limit),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(width: 4),
            const Icon(AppIcons.dropDown, size: 16),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCustomDialog(
  BuildContext context,
  int currentLimit,
  ValueChanged<int> onChanged,
) async {
  final result = await showDialog<int>(
    context: context,
    builder: (context) => _HistoryTopLimitDialog(initial: currentLimit),
  );
  if (result != null) {
    onChanged(result);
  }
}

class _HistoryTopLimitDialog extends StatefulWidget {
  const _HistoryTopLimitDialog({required this.initial});

  final int initial;

  @override
  State<_HistoryTopLimitDialog> createState() => _HistoryTopLimitDialogState();
}

class _HistoryTopLimitDialogState extends State<_HistoryTopLimitDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final text = widget.initial.toString();
    _controller = TextEditingController(text: text)
      ..selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed <= 0) return;
    final clamped = parsed.clamp(minCustomTopLimit, maxCustomTopLimit);
    Navigator.of(context).pop(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final loc = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.historyTopCustomDialogTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: l10n.historyTopCustomInputLabel,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.cancelButtonLabel),
        ),
        ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) {
            final parsed = int.tryParse(value.text.trim());
            final canSave = parsed != null && parsed > 0;
            return FilledButton(
              onPressed: canSave ? _submit : null,
              child: Text(loc.saveButtonLabel),
            );
          },
        ),
      ],
    );
  }
}
