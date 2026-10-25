import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../playback_controls.dart';
import '../seek_bar.dart';
import 'now_playing_artwork.dart';
import 'now_playing_auto_hide.dart';
import 'now_playing_seek_slot.dart';
import 'now_playing_split_geometry.dart';
import 'now_playing_track_info.dart';

/// First column of Split: the cover, the title, artist and album, the seek
/// slot and, under it, elapsed time | previous, play, next | total time. It
/// is always shown, outside the auto-hiding chrome, and keeps that chrome
/// shown while the pointer is on it, so the cursor does not vanish over the
/// seek track.
///
/// The cover's size comes from a fixed reserve for everything under it (see
/// [splitCoverSide]), and the content is laid out from the top of a block of
/// fixed height, so nothing moves when a title wraps or the album arrives.
class NowPlayingTrackColumn extends ConsumerWidget {
  const NowPlayingTrackColumn({super.key, required this.chrome});

  final AutoHideController chrome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerServiceProvider.select((s) => s.queue.current),
    );
    if (track == null) return const SizedBox.shrink();
    final titleStyle = nowPlayingTitleStyle(context);
    return AutoHidePin(
      controller: chrome,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = splitColumnPadding;
          final side = splitCoverSide(
            context,
            innerWidth: constraints.maxWidth - padding.horizontal,
            bodyHeight: constraints.maxHeight,
            titleStyle: titleStyle,
          );
          return Padding(
            padding: padding,
            // Centered as a block of fixed height, so its parts keep their
            // places whatever the text does. A window too short even for the
            // smallest cover scales the block down instead of overflowing.
            child: Center(
              child: FittedBox(
                child: SizedBox(
                  width: constraints.maxWidth - padding.horizontal,
                  height: side + splitReserve(context, titleStyle: titleStyle),
                  child: Column(
                    children: [
                      NowPlayingArtwork(size: side, radius: 32),
                      const SizedBox(height: splitCoverGap),
                      SizedBox(
                        height: splitTextReserve(
                          context,
                          titleStyle: titleStyle,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: NowPlayingTitle(track: track, lineIcons: true),
                        ),
                      ),
                      const SizedBox(height: splitSeekGap),
                      const SizedBox(
                        height: seekHitHeight,
                        child: NowPlayingSeekSlot(),
                      ),
                      const SizedBox(height: splitTransportGap),
                      const _TransportRow(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Elapsed time at the start, the transport buttons in the middle, total time
/// at the end.
class _TransportRow extends StatelessWidget {
  const _TransportRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          // A large text scale shrinks the label rather than the buttons.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SeekElapsedLabel(),
          ),
        ),
        PlaybackControls(transportOnly: true, spacing: 20),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: SeekDurationLabel(),
          ),
        ),
      ],
    );
  }
}
