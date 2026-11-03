import 'package:material_ui/material_ui.dart';

import '../../../core/database/history_queries.dart';
import '../../../core/database/library_database.dart' show LibraryDatabase;
import '../../../core/stats/listen_clear_scope.dart';
import '../../../l10n/l10n.dart';
import '../history_error_log.dart';
import 'history_clear_range.dart';

/// Asks which part of the History to clear, above the History modal. Resolves
/// to the bounds of the picked option, taken from the moment the dialog
/// opened, or `null` on Cancel, Esc or a tap outside.
///
/// [everythingPlays] is the number of listens in the whole history.
Future<ClearBounds?> showHistoryClearDialog(
  BuildContext context, {
  required LibraryDatabase db,
  required DateTime now,
  required int everythingPlays,
}) => showDialog<ClearBounds>(
  context: context,
  builder: (_) =>
      _HistoryClearDialog(db: db, now: now, everythingPlays: everythingPlays),
);

class _HistoryClearDialog extends StatefulWidget {
  const _HistoryClearDialog({
    required this.db,
    required this.now,
    required this.everythingPlays,
  });

  final LibraryDatabase db;
  final DateTime now;
  final int everythingPlays;

  @override
  State<_HistoryClearDialog> createState() => _HistoryClearDialogState();
}

class _HistoryClearDialogState extends State<_HistoryClearDialog> {
  /// `now` of this dialog: every option's bounds and count come from it.
  late final DateTime _now = widget.now;
  final _counts = <HistoryClearRange, int>{};
  final _failed = <HistoryClearRange>{};
  HistoryClearRange? _picked;

  @override
  void initState() {
    super.initState();
    _counts[HistoryClearRange.everything] = widget.everythingPlays;
    for (final range in HistoryClearRange.values) {
      if (range != HistoryClearRange.everything) _load(range);
    }
  }

  /// A failed count leaves the option without one, so it cannot be cleared;
  /// the option shows an error and [_retry] reads it again.
  Future<void> _load(HistoryClearRange range) async {
    _failed.remove(range);
    final bounds = range.bounds(_now);
    try {
      final summary = await widget.db.historyRangeSummary(
        bounds.from!,
        bounds.to!,
      );
      if (mounted) setState(() => _counts[range] = summary.plays);
    } on Object catch (error) {
      logHistoryError('Counting the listens to clear failed', error);
      if (mounted) setState(() => _failed.add(range));
    }
  }

  void _retry() {
    for (final range in _failed.toList()) {
      setState(() => _failed.remove(range));
      _load(range);
    }
  }

  String _label(HistoryClearRange range) {
    final l10n = context.l10n;
    return switch (range) {
      HistoryClearRange.lastHour => l10n.historyClearLastHour,
      HistoryClearRange.today => l10n.historyClearToday,
      HistoryClearRange.days7 => l10n.historyClearDays7,
      HistoryClearRange.everything => l10n.historyClearEverything,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final count = _picked == null ? null : _counts[_picked];
    return AlertDialog(
      title: Text(l10n.historyClearTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.historyClearBody),
            const SizedBox(height: 8),
            RadioGroup<HistoryClearRange>(
              groupValue: _picked,
              onChanged: (value) => setState(() => _picked = value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final range in HistoryClearRange.values)
                    RadioListTile<HistoryClearRange>(
                      key: ValueKey('history-clear-${range.name}'),
                      value: range,
                      title: Text(_label(range)),
                      subtitle: _counts[range] != null
                          ? Text(l10n.historyListenCount(_counts[range]!))
                          : _failed.contains(range)
                          ? Text(
                              l10n.historyClearCountFailed,
                              style: TextStyle(color: colors.error),
                            )
                          : null,
                    ),
                ],
              ),
            ),
            if (_failed.isNotEmpty)
              TextButton(
                key: const ValueKey('history-clear-retry'),
                onPressed: _retry,
                child: Text(l10n.historyClearRetry),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('history-clear-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: count != null && count > 0
              ? () => Navigator.of(context).pop(_picked!.bounds(_now))
              : null,
          child: Text(l10n.listenHistoryClearButton),
        ),
      ],
    );
  }
}
