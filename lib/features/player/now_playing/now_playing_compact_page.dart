import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../playback_controls.dart';
import '../seek_bar.dart';
import 'now_playing_actions.dart';
import 'now_playing_artwork.dart';
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
        // The cover alone in the middle; title, seek bar and controls form
        // a footer on the bottom edge, as on wide windows. `spaceBetween`
        // with an empty first child leaves equal space above and below the
        // cover. A window too short for both scrolls instead.
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox.shrink(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: NowPlayingArtwork(size: art, radius: 32),
                ),
                // Spacing as on SPlayer's phone layout: 24 under the title,
                // 30 under the seek bar, 30 under the buttons.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Heart and playlist sit by the title here.
                    NowPlayingTitle(
                      track: track,
                      centered: false,
                      trailing: const Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: [
                          NowPlayingFavoriteButton(),
                          NowPlayingPlaylistButton(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SeekBar(),
                    const SizedBox(height: 30),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: PlaybackControls(spread: true),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
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
