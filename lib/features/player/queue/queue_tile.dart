import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/format_duration.dart';
import '../../../shared/icons/app_icons.dart';
import 'queue_tile_menu.dart';

/// Fixed row height, which lets the list place and jump to rows without
/// measuring them.
const queueTileExtent = 64.0;

/// Largest text scale the fixed-height row's text grows to. Beyond it the two
/// text lines would no longer fit the row.
const _queueTileMaxTextScale = 1.25;

/// One queued track: drag handle, position (or an equalizer on the playing
/// one), title and artist, length and a remove button. Tapping plays it; a
/// right click, long press or the menu key opens its menu (the heart and
/// remove).
/// Tracks already played are dimmed; the playing one has the playing-song
/// colors (primaryContainer), the same while paused.
class QueueTile extends ConsumerWidget {
  const QueueTile({
    super.key,
    required this.track,
    required this.position,
    required this.current,
    required this.played,
    this.editable = true,
  });

  final Track track;

  /// Play position of this track in the queue.
  final int position;

  /// This is the track playing now.
  final bool current;

  /// This track comes before the playing one.
  final bool played;

  /// `false` for a row shown by the filter: no drag handle and no remove
  /// button, since the rows are not the whole queue. The row menu is kept.
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final player = ref.read(playerServiceProvider.notifier);
    final duration = track.duration;
    final textColor = current ? colors.onPrimaryContainer : null;

    final Widget leading;
    if (current) {
      leading = Icon(
        AppIcons.equalizerRounded,
        color: colors.onPrimaryContainer,
      );
    } else {
      leading = Text(
        '${position + 1}',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    return SizedBox(
      height: queueTileExtent,
      // The row height is fixed, so its text stops growing at a cap instead of
      // overflowing at the largest font sizes.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: _queueTileMaxTextScale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Opacity(
            opacity: played ? 0.6 : 1,
            child: QueueTileMenuRegion(
              track: track,
              position: position,
              child: Material(
                // A card: low-alpha fill so the dimmed screen behind the sheet
                // shows through; the playing one is opaque primaryContainer,
                // like the playing song row.
                color: current
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  // The playing row does nothing: tapping it must not restart
                  // the track.
                  onTap: current ? null : () => player.jump(position),
                  child: Row(
                    children: [
                      if (editable)
                        ReorderableDragStartListener(
                          index: position,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: Tooltip(
                              message: l10n.queueReorder,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  AppIcons.dragHandle,
                                  size: 20,
                                  color: current
                                      ? colors.onPrimaryContainer
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 36),
                      SizedBox(width: 32, child: Center(child: leading)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: textColor,
                              ),
                            ),
                            if (track.artist case final artist?)
                              Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: textColor ?? colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (duration != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            formatDuration(duration),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: current
                                  ? colors.onPrimaryContainer
                                  : colors.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      if (editable)
                        IconButton(
                          icon: const Icon(AppIcons.deleteRounded),
                          iconSize: 20,
                          color: current ? colors.onPrimaryContainer : null,
                          tooltip: l10n.queueRemove,
                          onPressed: () => player.removeTrack(position),
                        )
                      else
                        // As wide as the remove button, so durations line up.
                        const SizedBox(width: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
