import '../../../core/indexer/indexer_state.dart';
import '../../../l10n/l10n.dart';

/// One-line summary of a finished scan: counts, unreadable files and roots
/// that were left untouched.
String scanSummaryMessage(AppLocalizations l10n, ScanSummary summary) {
  final parts = [
    l10n.libraryScanFinished(summary.added, summary.updated, summary.removed),
    if (summary.failedTags > 0) l10n.libraryScanFailedTags(summary.failedTags),
    for (final entry in summary.skippedRoots.entries)
      switch (entry.value) {
        SkipReason.missing => l10n.libraryScanRootMissing(entry.key),
        SkipReason.empty => l10n.libraryScanRootEmpty(entry.key),
      },
  ];
  return parts.join('. ');
}
