import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../playback_controls.dart';
import '../seek_bar.dart';
import 'now_playing_actions.dart';
import 'now_playing_track_info.dart';

/// Now Playing page of a narrow window: cover, title and artist, then the
/// controls and the seek bar (close and queue are in the header, and volume
/// is left to the system on a narrow window). Scrolls rather than
/// overflowing in a very short window.
class NowPlayingCompactPage extends ConsumerWidget {
  const NowPlayingCompactPage({super.key});

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
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PlaybackControls(),
                ),
                const SeekBar(),
              ],
            ),
          ),
        );
      },
    );
  }
}
