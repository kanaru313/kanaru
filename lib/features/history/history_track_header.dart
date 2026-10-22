import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/cover_art.dart';

/// Size of the cover in the header.
const _coverSize = 96.0;

/// Top of a song's history page: cover, the totals ("N listens · First …
/// · Last …", from `play_stats`) and the Play button. Play only shows for a
/// song in the library; [onPlay] is null for any other.
class HistoryTrackHeader extends ConsumerWidget {
  const HistoryTrackHeader({
    super.key,
    required this.summary,
    required this.onPlay,
  });

  final HistoryTrackSummary summary;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    final track = summary.track;
    final first = summary.firstPlayedAt;
    final last = summary.lastPlayedAt;
    final stats = <String>[
      if (summary.count > 0) ...[
        l10n.historyTrackStats(summary.count),
        if (first != null)
          l10n.historyTrackFirst(
            dates.formatMediumDate(DateTime.fromMillisecondsSinceEpoch(first)),
          ),
        if (last != null)
          l10n.historyTrackLast(
            _dayAndTime(
              context,
              dates,
              DateTime.fromMillisecondsSinceEpoch(last),
            ),
          ),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 12),
      child: Row(
        children: [
          CoverArt(
            path: coverPath(
              ref.watch(coverCacheDirectoryProvider),
              track?.coverKey,
            ),
            size: _coverSize,
            placeholder: Center(
              child: Icon(
                track == null ? AppIcons.musicOff : AppIcons.musicNoteOutlined,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stats.isNotEmpty)
                  Text(stats.join(' · '), style: theme.textTheme.bodyMedium),
                if (onPlay != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(AppIcons.play),
                    label: Text(l10n.historyPlay),
                    onPressed: onPlay,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dayAndTime(
    BuildContext context,
    MaterialLocalizations dates,
    DateTime at,
  ) =>
      '${dates.formatMediumDate(at)} '
      '${dates.formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}
