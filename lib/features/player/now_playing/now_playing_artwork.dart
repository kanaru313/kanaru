import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../core/player/playing_track_art.dart';
import '../../../core/player/playing_track_original_cover.dart';
import '../track_artwork.dart';

/// Large cover of the playing track: its thumbnail at once, the full-size
/// cover over it when that has been read and decoded. Only Now Playing is
/// large enough to need the original; the player bar and media controls
/// keep the thumbnail.
class NowPlayingArtwork extends ConsumerWidget {
  const NowPlayingArtwork({super.key, required this.size, this.radius = 8});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = ref.watch(
      playerServiceProvider.select((s) => s.queue.current?.uri),
    );
    final original = ref.watch(playingTrackOriginalCoverProvider).value;
    return TrackArtwork(
      artUri: ref.watch(playingTrackArtProvider),
      size: size,
      radius: radius,
      layered: true,
      // The value of the previous track can outlive a track change until the
      // next one is read.
      original: original != null && original.uri == uri ? original : null,
    );
  }
}
