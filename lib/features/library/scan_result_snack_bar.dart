import 'package:material_ui/material_ui.dart';

import '../../core/indexer/indexer_state.dart';
import '../../l10n/l10n.dart';

/// How a finished scan went, which picks the icon and title.
enum _Outcome { done, warning, failed }

/// How long a finished or failed scan is still news.
const scanResultMaxAge = Duration(seconds: 10);

/// Whether [state] is a scan result worth announcing: it ended less than
/// [scanResultMaxAge] before [now]. A screen that only gets to see an old
/// result (it was hidden, or mounted later) stays quiet.
bool isFreshScanResult(IndexerState state, {DateTime? now}) {
  final at = switch (state) {
    IndexerFinished(:final at) => at,
    IndexerFailed(:final at) => at,
    _ => null,
  };
  return at != null &&
      (now ?? DateTime.now()).difference(at) < scanResultMaxAge;
}

/// Floating snack bar that reports a finished or failed scan: a status icon,
/// a short title and one line of details. Uses a surface container color
/// rather than the default inverse surface, so it sits quietly on the page in
/// both themes. Returns `null` for states that need no report, and for a
/// result that is no longer fresh ([isFreshScanResult]).
SnackBar? scanResultSnackBar(BuildContext context, IndexerState state) {
  if (!isFreshScanResult(state)) return null;
  // The scan at app start only speaks up when it changed the library.
  if (state case IndexerFinished(:final quiet, :final summary)
      when quiet && summary.added + summary.updated + summary.removed == 0) {
    return null;
  }
  final l10n = context.l10n;
  final (outcome, details) = switch (state) {
    IndexerFinished(:final summary) => (
      summary.failedTags > 0 ||
              summary.undecodableNames > 0 ||
              summary.skippedRoots.isNotEmpty
          ? _Outcome.warning
          : _Outcome.done,
      _summaryDetails(l10n, summary),
    ),
    // The technical message goes to the log, not to the user.
    IndexerFailed() => (_Outcome.failed, l10n.libraryScanFailedDetails),
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
    if (summary.undecodableNames > 0)
      l10n.libraryScanUndecodableNames(summary.undecodableNames),
    for (final entry in summary.skippedRoots.entries)
      switch (entry.value) {
        SkipReason.missing => l10n.libraryScanRootMissing(entry.key),
        SkipReason.empty => l10n.libraryScanRootEmpty(entry.key),
        SkipReason.timedOut => l10n.libraryScanRootTimedOut(entry.key),
        SkipReason.readerStuck => l10n.libraryScanRootReaderStuck(entry.key),
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
