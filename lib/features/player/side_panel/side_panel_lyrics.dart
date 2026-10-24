import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/playing_track_lyrics_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/empty_state.dart';
import '../lyrics/lyrics_view.dart';
import '../now_playing/now_playing_open_provider.dart';

/// Lyrics tab of the docked side panel. Reads the lyrics only while it is
/// built, which is while the tab is shown, and shows nothing while Now
/// Playing is open: the shell stays built under it, and two lyrics views
/// would follow the same playback.
class SidePanelLyrics extends ConsumerWidget {
  const SidePanelLyrics({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(nowPlayingOpenProvider)) return const SizedBox.shrink();
    final lyrics = ref.watch(playingTrackLyricsProvider);
    // While the next track's lyrics load the value is still the previous
    // track's, and `null` has no uri to tell them apart: say nothing until
    // the load ends.
    if (lyrics.isLoading) return const SizedBox.shrink();
    if (lyrics.value == null) {
      return EmptyState(icon: AppIcons.lyrics, title: context.l10n.lyricsNone);
    }
    return const LyricsView();
  }
}
