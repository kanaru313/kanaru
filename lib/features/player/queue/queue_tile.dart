import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/format_duration.dart';
import '../../../shared/icons/app_icons.dart';

/// Fixed row height, which lets the list place and jump to rows without
/// measuring them.
const queueTileExtent = 64.0;

/// One queued track: drag handle, position (or an equalizer on the playing
/// one), title and artist, length and a remove button. Tapping plays it.
/// Tracks already played are dimmed; the playing one is tinted.
class QueueTile extends ConsumerWidget {
  const QueueTile({
    super.key,
    required this.track,
    required this.position,
    required this.current,
    required this.played,
  });

  final Track track;

  /// Play position of this track in the queue.
  final int position;

  /// This is the track playing now.
  final bool current;

  /// This track comes before the playing one.
  final bool played;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final player = ref.read(playerServiceProvider.notifier);
    final duration = track.duration;
    final textColor = current ? colors.primary : null;

    final Widget leading;
    if (current) {
      final playing = ref.watch(playerServiceProvider.select((s) => s.playing));
      leading = Icon(
        playing ? AppIcons.equalizerRounded : AppIcons.musicNoteRounded,
        color: colors.primary,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Opacity(
          opacity: played ? 0.6 : 1,
          child: Material(
            // A card: low-alpha fill so the dimmed screen behind the sheet
            // shows through; the playing one is tinted and outlined.
            color: current
                ? colors.primary.withValues(alpha: 0.12)
                : colors.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: current
                  ? BorderSide(color: colors.primary.withValues(alpha: 0.6))
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              // The playing row does nothing: tapping it must not restart
              // the track.
              onTap: current ? null : () => player.jump(position),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: position,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Tooltip(
                        message: l10n.queueReorder,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(AppIcons.dragHandle, size: 20),
                        ),
                      ),
                    ),
                  ),
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
                          color: colors.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(AppIcons.deleteRounded),
                    iconSize: 20,
                    tooltip: l10n.queueRemove,
                    onPressed: () => player.removeTrack(position),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
