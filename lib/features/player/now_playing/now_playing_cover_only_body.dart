import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../playback_controls.dart';
import '../seek_bar.dart';
import 'now_playing_artwork.dart';
import 'now_playing_auto_hide.dart';
import 'now_playing_seek_slot.dart';
import 'now_playing_split_geometry.dart'
    show splitCoverGap, splitSeekGap, splitTextReserve, splitTransportHeight;
import 'now_playing_track_info.dart';

const _sideMargin = 32.0;
const _verticalMargin = 16.0;
const _minCoverSide = 96.0;
const _overlayMaxWidth = 560.0;

/// Body of Cover only: the cover as large as the height allows, centered,
/// with the title and the artist and album lines (as in Split) under it that
/// always show. Under those, the seek slot and the transport buttons fade with [chrome].
///
/// The room for the text (two title lines, the artist and the album line) and for the controls
/// is reserved for the current text scale whatever shows, so the cover never
/// resizes when the controls fade, a title wraps or the album arrives late.
class NowPlayingCoverOnlyBody extends ConsumerWidget {
  const NowPlayingCoverOnlyBody({super.key, required this.chrome});

  final AutoHideController chrome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerServiceProvider.select((s) => s.queue.current),
    );
    if (track == null) return const SizedBox.shrink();
    final titleStyle = nowPlayingTitleStyle(context);
    final textReserve = splitTextReserve(context, titleStyle: titleStyle);
    final seekHeight = ref.watch(nowPlayingSeekSlotHeightProvider);
    final seekReserve = math.max(
      seekHeight,
      MediaQuery.textScalerOf(context).scale(12 * 1.5),
    );
    final controlsReserve = seekReserve + splitSeekGap + splitTransportHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final innerWidth = constraints.maxWidth - _sideMargin * 2;
        final side = math
            .min(
              innerWidth,
              constraints.maxHeight -
                  _verticalMargin * 2 -
                  splitCoverGap * 2 -
                  textReserve -
                  controlsReserve,
            )
            .clamp(_minCoverSide, double.infinity);
        return Center(
          // A window too short even for the smallest cover scales the block
          // down instead of overflowing.
          child: FittedBox(
            child: SizedBox(
              width: innerWidth,
              height: side + splitCoverGap * 2 + textReserve + controlsReserve,
              child: Column(
                children: [
                  NowPlayingArtwork(size: side, radius: 32),
                  const SizedBox(height: splitCoverGap),
                  SizedBox(
                    height: textReserve,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.max(side, _overlayMaxWidth),
                        ),
                        child: NowPlayingTitle(track: track, lineIcons: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: splitCoverGap),
                  SizedBox(
                    height: controlsReserve,
                    child: AutoHide(
                      controller: chrome,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _overlayMaxWidth,
                          ),
                          child: Column(
                            children: [
                              SeekBar(
                                track: const NowPlayingSeekSlot(),
                                trackHeight: seekHeight,
                              ),
                              const SizedBox(height: splitSeekGap),
                              const PlaybackControls(
                                transportOnly: true,
                                spacing: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
