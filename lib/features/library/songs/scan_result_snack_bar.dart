import 'package:material_ui/material_ui.dart';

import '../../../core/indexer/indexer_state.dart';
import '../../../l10n/l10n.dart';

/// How a finished scan went, which picks the icon and title.
enum _Outcome { done, warning, failed }

/// Floating snack bar that reports a finished or failed scan: a status icon,
/// a short title and one line of details. Uses a surface container color
/// rather than the default inverse surface, so it sits quietly on the page in
/// both themes. Returns `null` for states that need no report.
SnackBar? scanResultSnackBar(BuildContext context, IndexerState state) {
  final l10n = context.l10n;
  final (outcome, details) = switch (state) {
    IndexerFinished(:final summary) => (
      summary.failedTags > 0 || summary.skippedRoots.isNotEmpty
          ? _Outcome.warning
          : _Outcome.done,
      _summaryDetails(l10n, summary),
    ),
    IndexerFailed(:final message) => (_Outcome.failed, message),
    _ => (null, null),
  };
  if (outcome == null || details == null) return null;

  final colors = Theme.of(context).colorScheme;
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    width: 440,
    duration: const Duration(seconds: 5),
    backgroundColor: colors.surfaceContainerHigh,
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    showCloseIcon: true,
    closeIconColor: colors.onSurfaceVariant,
    content: _ScanResultContent(
      outcome: outcome,
      title: switch (outcome) {
        _Outcome.done => l10n.libraryScanDoneTitle,
        _Outcome.warning => l10n.libraryScanWarningTitle,
        _Outcome.failed => l10n.libraryScanFailedTitle,
      },
      details: details,
    ),
  );
}

/// "4 new · 1 updated", leaving out zero counts, then unreadable files and
/// skipped roots on their own lines.
String _summaryDetails(AppLocalizations l10n, ScanSummary summary) {
  final counts = [
    if (summary.added > 0) l10n.libraryScanAdded(summary.added),
    if (summary.updated > 0) l10n.libraryScanUpdated(summary.updated),
    if (summary.removed > 0) l10n.libraryScanRemoved(summary.removed),
  ];
  return [
    counts.isEmpty ? l10n.libraryScanNoChanges : counts.join(' · '),
    if (summary.failedTags > 0) l10n.libraryScanFailedTags(summary.failedTags),
    for (final entry in summary.skippedRoots.entries)
      switch (entry.value) {
        SkipReason.missing => l10n.libraryScanRootMissing(entry.key),
        SkipReason.empty => l10n.libraryScanRootEmpty(entry.key),
      },
  ].join('\n');
}

class _ScanResultContent extends StatelessWidget {
  const _ScanResultContent({
    required this.outcome,
    required this.title,
    required this.details,
  });

  final _Outcome outcome;
  final String title;
  final String details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, iconColor) = switch (outcome) {
      _Outcome.done => (Icons.check_circle_rounded, colors.primary),
      _Outcome.warning => (Icons.warning_amber_rounded, colors.tertiary),
      _Outcome.failed => (Icons.error_rounded, colors.error),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                details,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
