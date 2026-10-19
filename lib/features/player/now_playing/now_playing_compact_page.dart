import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../playback_controls.dart';
import '../queue/queue_button.dart';
import '../seek_bar.dart';
import '../volume_button.dart';
import 'now_playing_actions.dart';
import 'now_playing_track_info.dart';

/// Now Playing page of a narrow window: cover, title and artist, then the
/// controls, the seek bar and close/queue. Scrolls rather than overflowing
/// in a very short window.
class NowPlayingCompactPage extends ConsumerWidget {
  const NowPlayingCompactPage({
    super.key,
    required this.onClose,
    required this.onShowQueue,
  });

  final VoidCallback onClose;

  /// Switches to the queue page rather than opening a drawer.
  final VoidCallback onShowQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerServiceProvider.select((s) => s.queue.current),
    );
    if (track == null) return const SizedBox.shrink();
    final windowHeight = MediaQuery.sizeOf(context).height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final art = (constraints.maxWidth - 48)
            .clamp(0.0, windowHeight * 0.45)
            .toDouble();
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                // Heart and playlist sit by the title here, not in a footer.
                NowPlayingTrackInfo(
                  track: track,
                  artworkSize: art,
                  centered: false,
                  titleTrailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NowPlayingFavoriteButton(),
                      NowPlayingPlaylistButton(),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: PlaybackControls(),
                      ),
                    ),
                    const VolumeButton(),
                  ],
                ),
                const SeekBar(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NowPlayingCloseButton(onPressed: onClose),
                    QueueButton(onPressed: onShowQueue),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
