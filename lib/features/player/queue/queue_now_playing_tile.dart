import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../track_artwork.dart';
import 'queue_playing_indicator.dart';
import 'queue_row_actions.dart';
import 'queue_row_extent.dart';
import 'queue_row_text.dart';
import 'queue_tile_menu.dart';

/// Side of the cover of the Now playing row.
const queueNowPlayingCoverSize = 56.0;

/// The row of the playing track: a larger cover, the title in the primary
/// color on a tinted card, an equalizer while audio plays, and a remove
/// button on hover or keyboard focus. Tapping it does nothing (it must not
/// restart the track), it cannot be dragged and it has no swipe, so a stray
/// swipe cannot cut off the song being heard. The row menu is kept.
class QueueNowPlayingTile extends ConsumerWidget {
  const QueueNowPlayingTile({
    super.key,
    required this.track,
    required this.position,
  });

  final Track track;

  /// Play position of the track in the queue.
  final int position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final player = ref.read(playerServiceProvider.notifier);
    return SizedBox(
      height: queueNowPlayingExtent(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: QueueTileMenuRegion(
          track: track,
          position: position,
          child: QueueRowReveal(
            builder: (context, revealed) => Material(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: Semantics(
                customSemanticsActions: {
                  CustomSemanticsAction(label: context.l10n.queueRemove): () =>
                      player.removeTrack(position),
                },
                child: InkWell(
                  // Does nothing, but a row that takes taps is a stop of the
                  // focus order, which is how a keyboard user reaches the
                  // remove button hidden in it. It looks and reads as inert: no
                  // splash, an arrow cursor, no tap action for screen readers.
                  onTap: () {},
                  excludeFromSemantics: true,
                  splashFactory: NoSplash.splashFactory,
                  mouseCursor: SystemMouseCursors.basic,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        const PlayingTrackArtwork(
                          size: queueNowPlayingCoverSize,
                          radius: 8,
                        ),
                        const SizedBox(width: 12),
                        QueueRowText(
                          track: track,
                          titleColor: colors.primary,
                          artistColor: colors.primary,
                        ),
                        const QueuePlayingIndicator(),
                        QueueRowDuration(track: track),
                        QueueRowActions(
                          revealed: revealed,
                          onRemove: () => player.removeTrack(position),
                        ),
                      ],
                    ),
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
