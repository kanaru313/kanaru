import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/playing_track_lyrics_provider.dart';
import '../../../core/player/player_service.dart';
import 'plain_lyrics_view.dart';
import 'synced_lyrics_view.dart';

/// Lyrics of the playing track for Now Playing: synced lyrics follow
/// playback, plain lyrics are shown as they are. Shows nothing while the
/// current track's lyrics load (the value may still be the previous
/// track's) or when it has none.
class LyricsView extends ConsumerWidget {
  const LyricsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = ref.watch(
      playerServiceProvider.select((s) => s.queue.current?.uri),
    );
    final playing = ref.watch(playingTrackLyricsProvider).value;
    if (playing == null || playing.uri != uri) return const SizedBox.expand();
    final lyrics = playing.lyrics;
    // A new key per lyrics resets the scroll position and line state.
    return lyrics.synced
        ? SyncedLyricsView(key: ObjectKey(lyrics), lyrics: lyrics)
        : PlainLyricsView(key: ObjectKey(lyrics), lyrics: lyrics);
  }
}

/// Whether Now Playing should make room for lyrics: the playing track's
/// lyrics, or while the next track's load, the previous ones (so the layout
/// does not jump on every track change). Only watched while Now Playing is
/// shown.
final nowPlayingHasLyricsProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(playingTrackLyricsProvider).value != null,
);
