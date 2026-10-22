import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/cover_art.dart';
import '../../shared/widgets/song_tile.dart' show songCoverSize;

/// Fixed height of every line of the timeline (day headers too), which lets
/// the list place lines without measuring them.
const historyRowExtent = 64.0;

/// One play: cover, title with "artist · album", the "Nth listen" badge, the
/// time it started and a more button. A play whose file is not in the library
/// shows its file name, is dimmed and does not play.
///
/// The menu opens on a right click, a long press and the more button, always
/// through [onMenu] with the pointer position. Removing a play is only in
/// that menu, never one tap on the row: the list moves under the pointer when
/// plays come and go.
class HistoryPlayTile extends ConsumerWidget {
  const HistoryPlayTile({
    super.key,
    required this.row,
    required this.onTap,
    required this.onMenu,
  });

  final HistoryPlayRow row;

  /// Plays from this row; null on a play that cannot play.
  final VoidCallback? onTap;

  /// Opens the menu with its corner at the given global position.
  final ValueChanged<Offset> onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final track = row.track;
    final details = [
      track?.artist,
      track?.album,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(row.playedAt)),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final small = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final nth = row.nth;

    final content = Row(
      children: [
        const SizedBox(width: 12),
        CoverArt(
          path: coverPath(
            ref.watch(coverCacheDirectoryProvider),
            track?.coverKey,
          ),
          size: songCoverSize,
          placeholder: Center(
            child: Icon(
              track == null ? AppIcons.musicOff : AppIcons.musicNoteOutlined,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track?.title ?? row.path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
              if (track == null || details.isNotEmpty)
                Text(
                  track == null ? l10n.historyTrackMissing : details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small,
                ),
            ],
          ),
        ),
        if (nth != null)
          Tooltip(
            message: l10n.historyNthPlayLabel(nth),
            child: Semantics(
              label: l10n.historyNthPlayLabel(nth),
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(l10n.historyNthPlay(nth), style: small),
              ),
            ),
          ),
        Text(
          time,
          style: small?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(AppIcons.more),
            iconSize: 20,
            tooltip: l10n.historyMore,
            onPressed: () {
              final box = context.findRenderObject()! as RenderBox;
              onMenu(box.localToGlobal(Offset(0, box.size.height)));
            },
          ),
        ),
      ],
    );

    return SizedBox(
      height: historyRowExtent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Opacity(
          opacity: track == null ? 0.6 : 1,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onSecondaryTapUp: (d) => onMenu(d.globalPosition),
            onLongPressStart: (d) => onMenu(d.globalPosition),
            child: Material(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: content),
            ),
          ),
        ),
      ),
    );
  }
}
