import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'now_playing_title_bar.dart';
import 'now_playing_track_info.dart';

/// Header strip of the wide layout: the lyrics-only toggle at the top left,
/// shown only when there are lyrics to show. [AutoHide] fades it with the
/// rest of the chrome.
class NowPlayingWideHeader extends StatelessWidget {
  const NowPlayingWideHeader({
    super.key,
    required this.height,
    required this.excludeFromDrag,
    required this.hasLyrics,
    required this.lyricsOnly,
    required this.onToggleLyricsOnly,
  });

  final double height;
  final NowPlayingDragExclusion excludeFromDrag;
  final bool hasLyrics;
  final bool lyricsOnly;
  final VoidCallback onToggleLyricsOnly;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: hasLyrics
          ? Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 30),
                child: excludeFromDrag(
                  IconButton(
                    icon: const Icon(AppIcons.lyrics),
                    isSelected: lyricsOnly,
                    tooltip: context.l10n.nowPlayingLyricsOnly,
                    onPressed: onToggleLyricsOnly,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// Body of the wide layout between header and footer. By default the cover
/// block is centered, or takes the left half when there are [lyrics] (shown
/// on the right half). In [lyricsOnly] mode a compact title and artist sit
/// centered at the top and the lyrics fill the rest.
class NowPlayingWideBody extends ConsumerWidget {
  const NowPlayingWideBody({super.key, this.lyrics, this.lyricsOnly = false});

  /// Lyrics view; `null` while the app has none.
  final Widget? lyrics;
  final bool lyricsOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerServiceProvider.select((s) => s.queue.current),
    );
    final lyrics = this.lyrics;
    if (track == null) return const SizedBox.shrink();
    if (lyrics != null && lyricsOnly) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: NowPlayingCompactInfo(track: track),
          ),
          Expanded(child: lyrics),
        ],
      );
    }
    final windowHeight = MediaQuery.sizeOf(context).height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final blockWidth = lyrics != null
            ? constraints.maxWidth / 2
            : constraints.maxWidth;
        // 70% of the block, at most half the window, and leaving room for
        // the title and artist below.
        final art = [
          blockWidth * 0.7,
          windowHeight * 0.5,
          constraints.maxHeight - 140,
        ].reduce((a, b) => a < b ? a : b).clamp(96.0, double.infinity);
        return Row(
          children: [
            SizedBox(
              width: blockWidth,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: NowPlayingTrackInfo(track: track, artworkSize: art),
                ),
              ),
            ),
            if (lyrics != null) Expanded(child: lyrics),
          ],
        );
      },
    );
  }
}
