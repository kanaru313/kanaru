import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/scan_stats_queries.dart';
import '../../core/indexer/scan_stats.dart';
import '../../l10n/l10n.dart';
import 'scan_stats_provider.dart';

/// What the scan did, as rows without a control (laid out like
/// `LibraryStatsRow`): the songs stored out of the music files seen, the
/// files the scan rules left out by reason, the songs stored without tags,
/// and the covers made. The songs, tag errors and covers come from the
/// database; what only a scan knows (files seen, left out, and the songs
/// stored for the folders it finished, to set against the files seen) comes
/// from the latest scan of this session, and reads "not scanned" until there
/// is one.
/// Hidden without a library; "…" until the first count is in, "—" if it
/// fails, and the last count is kept if a later reload fails.
class ScanStatsRows extends ConsumerWidget {
  const ScanStatsRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(scanDbStatsProvider);
    // Loaded, and there is no library to count.
    if (db.hasValue && db.value == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final session = ref.watch(lastScanStatsProvider);
    final counts = db.value;
    final placeholder = db.hasError ? '—' : '…';
    final notScanned = l10n.scanStatsNotScanned;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatLine(
          title: l10n.scanStatsTracksTitle,
          value: counts == null
              ? placeholder
              : session == null
              ? '${l10n.scanStatsSongs(counts.tracks)} · $notScanned'
              // Stored and seen are both counted over the roots the scan
              // finished, so the first never exceeds the second by rows of
              // a folder that was missing.
              : l10n.scanStatsTracksOfFiles(session.stored, session.seen),
          note: session != null && session.unfinishedRoots > 0
              ? l10n.scanStatsUnfinishedRoots(session.unfinishedRoots)
              : null,
        ),
        _StatLine(
          title: l10n.scanStatsLeftOutTitle,
          value: session == null ? notScanned : _leftOut(context, session),
        ),
        _StatLine(
          title: l10n.scanStatsTagErrorsTitle,
          value: counts == null
              ? placeholder
              : l10n.scanStatsTagErrors(counts.tagErrors),
        ),
        _StatLine(
          title: l10n.scanStatsCoversTitle,
          value: counts == null ? placeholder : _covers(context, counts),
          note: l10n.scanStatsCoversHint,
        ),
      ],
    );
  }

  static String _leftOut(BuildContext context, ScanStats stats) {
    final l10n = context.l10n;
    return [
      l10n.scanStatsNomedia(stats.nomedia),
      l10n.scanStatsExcluded(stats.excluded),
      l10n.scanStatsTooSmall(stats.tooSmall),
      l10n.scanStatsTooShort(stats.tooShort),
    ].join(' · ');
  }

  static String _covers(BuildContext context, ScanDbStats counts) =>
      context.l10n.scanStatsCovers(counts.covers, counts.withCover);
}

/// One row: a title, its value under it, and an optional smaller note.
class _StatLine extends StatelessWidget {
  const _StatLine({required this.title, required this.value, this.note});

  final String title;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.bodyLarge),
            Text(value, style: muted),
            if (note case final note?) Text(note, style: muted),
          ],
        ),
      ),
    );
  }
}
