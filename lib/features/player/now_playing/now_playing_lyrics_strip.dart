import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../l10n/l10n.dart';
import '../playback_controls.dart';
import '../seek_bar.dart';
import '../track_artwork.dart';
import 'now_playing_seek_slot.dart';
import 'now_playing_split_geometry.dart' show splitTransportHeight;

const _minStripHeight = 72.0;
const _coverSide = 48.0;
const _textMaxWidth = 240.0;
const _verticalPadding = 12.0;
const _rowSpacing = 12.0;

/// The seek track keeps at least this much width; the title and artist give
/// way before it shrinks.
const _minTrackWidth = 160.0;

/// Below this width the title and artist are left out instead of cut to a
/// few letters.
const _minTextWidth = 72.0;

/// Width of the previous, play and next buttons with the gaps between them.
const _transportWidth = 48.0 + splitTransportHeight + 48.0 + 4.0 * 2;

/// Width of the two time labels and the gaps around the track in the seek
/// bar, at the default text scale (a label like "10:00" is about 34 px).
const _seekChromeWidth = 34.0 * 2 + 8.0 * 2;

/// Height of the strip under the lyrics: 72 px, more once the text scale
/// makes the two text lines or the filled play button taller than that.
double lyricsStripHeight(BuildContext context) {
  // Title (16 px) and artist (12 px) lines plus the strip's own padding.
  final lines = MediaQuery.textScalerOf(context).scale(16 * 1.5 + 12 * 1.5);
  return math.max(
    _minStripHeight,
    math.max(lines, splitTransportHeight) + _verticalPadding * 2,
  );
}

/// The strip that overlays the bottom of Lyrics only: the cover (a button
/// back to Split), title and artist, then elapsed time | seek slot | total
/// time and previous, play, next. It fades into the surface above it so the
/// lyrics read over any line. The caller places it and hides it with the
/// rest of the chrome.
class NowPlayingLyricsStrip extends ConsumerWidget {
  const NowPlayingLyricsStrip({super.key, required this.onShowSplit});

  /// Called when the cover is pressed.
  final VoidCallback onShowSplit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerServiceProvider.select((s) => s.queue.current),
    );
    final seekHeight = ref.watch(nowPlayingSeekSlotHeightProvider);
    if (track == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Clear at the top, then 85% surface behind the whole content row.
          stops: const [0, 0.25, 1],
          colors: [
            surface.withValues(alpha: 0),
            surface.withValues(alpha: 0.85),
            surface.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: SizedBox(
        height: lyricsStripHeight(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: _verticalPadding,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              // What the row spends on everything but the text: the cover,
              // the buttons, the time labels and the three gaps.
              final fixed =
                  _coverSide +
                  _transportWidth +
                  _seekChromeWidth * scale +
                  _rowSpacing * 3;
              final textMax = (constraints.maxWidth - fixed - _minTrackWidth)
                  .clamp(0.0, _textMaxWidth);
              return Row(
                spacing: _rowSpacing,
                children: [
                  Tooltip(
                    message: context.l10n.nowPlayingViewSplit,
                    child: Stack(
                      children: [
                        const PlayingTrackArtwork(size: _coverSide),
                        // The ink sits on top of the artwork so a hover or
                        // press shows on the cover itself.
                        Positioned.fill(
                          child: Material(
                            type: MaterialType.transparency,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: onShowSplit,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (textMax >= _minTextWidth)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: textMax),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (track.artist case final artist?)
                            Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: SeekBar(
                      track: const NowPlayingSeekSlot(),
                      trackHeight: seekHeight,
                    ),
                  ),
                  const PlaybackControls(transportOnly: true),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
