import 'package:material_ui/material_ui.dart';

import '../../core/indexer/indexer_state.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/app_snack_bar.dart';

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

/// Snack bar that reports a finished or failed scan: a status icon, a short
/// title and one line of details. Its frame comes from the app theme. Returns
/// `null` for states that need no report, and for a result that is no longer
/// fresh ([isFreshScanResult]).
SnackBar? scanResultSnackBar(BuildContext context, IndexerState state) {
  if (!isFreshScanResult(state)) return null;
  // The scan at app start only speaks up when it changed the library, and
  // then only about the changes: Settings already marks a missing folder.
  final quiet = state is IndexerFinished && state.quiet;
  if (state case IndexerFinished(:final summary)
      when quiet && summary.added + summary.updated + summary.removed == 0) {
    return null;
  }
  final l10n = context.l10n;
  final (outcome, details) = switch (state) {
    IndexerFinished(:final summary) => (
      summary.failedTags > 0 ||
              summary.undecodableNames > 0 ||
              (!quiet && summary.skippedRoots.isNotEmpty)
          ? AppSnackBarKind.warning
          : AppSnackBarKind.success,
      _summaryDetails(l10n, summary, quiet: quiet),
    ),
    // The technical message goes to the log, not to the user.
    IndexerFailed() => (AppSnackBarKind.error, l10n.libraryScanFailedDetails),
    _ => (null, null),
  };
  if (outcome == null || details == null) return null;

  return appSnackBar(
    kind: outcome,
    title: switch (outcome) {
      AppSnackBarKind.success => l10n.libraryScanDoneTitle,
      AppSnackBarKind.warning => l10n.libraryScanWarningTitle,
      _ => l10n.libraryScanFailedTitle,
    },
    details: details,
    duration: const Duration(seconds: 5),
  );
}

/// "4 new · 1 updated", leaving out zero counts, then unreadable files and
/// skipped roots on their own lines (not for a [quiet] scan).
String _summaryDetails(
  AppLocalizations l10n,
  ScanSummary summary, {
  required bool quiet,
}) {
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
    if (!quiet)
      for (final entry in summary.skippedRoots.entries)
        switch (entry.value) {
          SkipReason.missing => l10n.libraryScanRootMissing(entry.key),
          SkipReason.empty => l10n.libraryScanRootEmpty(entry.key),
          SkipReason.timedOut => l10n.libraryScanRootTimedOut(entry.key),
          SkipReason.readerStuck => l10n.libraryScanRootReaderStuck(entry.key),
        },
  ].join('\n');
}
