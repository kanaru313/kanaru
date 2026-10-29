import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/online/playing_lyrics_status_provider.dart';
import '../../../core/player/player_service.dart';
import 'lyrics_found_body.dart';
import 'lyrics_status_states.dart';

/// The lyrics slot of Now Playing, drawn from the playing song's lyrics
/// status: nothing while it is read, a pulsing bar while an online lookup
/// runs, the lyrics (with the online source's credit when they came from the
/// web) once found, and the empty state with the ways to find some
/// otherwise. A status that is not the playing track's yet shows nothing, so
/// the previous track's words never flash. The slot is the same in every
/// state; the layout around it never changes with them.
class LyricsView extends ConsumerWidget {
  const LyricsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = ref.watch(
      playerServiceProvider.select((s) => s.queue.current?.uri),
    );
    final status = ref.watch(playingLyricsStatusProvider);
    if (status == null || status.uri != uri) return const SizedBox.expand();
    return switch (status) {
      LyricsReading() => const SizedBox.expand(),
      LyricsSearching(:final providerId) => LyricsSearchingView(
        providerId: providerId,
      ),
      LyricsFound() => LyricsFoundBody(found: status),
      LyricsNone() => LyricsNoneView(none: status),
    };
  }
}
