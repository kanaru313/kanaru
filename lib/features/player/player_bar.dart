import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/playback_error.dart';
import '../../core/player/player_service.dart';
import '../../l10n/l10n.dart';
import 'format_duration.dart';
import 'now_playing_summary.dart';
import 'open_media.dart';
import 'playback_controls.dart';
import 'seek_strip.dart';
import 'volume_button.dart';

const playerBarHeight = 96.0;

/// Whether the shell shows the player bar: only when there is something to
/// play, or while a folder scan is filling the queue.
final playerBarVisibleProvider = Provider<bool>(
  (ref) =>
      ref.watch(openMediaProvider) ||
      !ref.watch(playerServiceProvider.select((s) => s.queue.isEmpty)),
);

/// Below this width the time label is hidden.
const _timeBreakpoint = 600.0;

/// Below this width the cover is hidden, leaving the title more room.
const _coverBreakpoint = 720.0;

/// Below this width shuffle and repeat are hidden too.
const _compactBreakpoint = 560.0;

/// Gap between a button's center and its tooltip: half the play/pause
/// button plus some air, so the tooltip clears the hover highlight.
const _tooltipOffset = 34.0;

/// Full-width bar at the bottom of the window: seek strip on the top edge,
/// track summary on the left, playback controls in the middle, time and
/// volume on the right. Shows a snack bar for the latest track that failed.
class PlayerBar extends ConsumerStatefulWidget {
  const PlayerBar({super.key});

  @override
  ConsumerState<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends ConsumerState<PlayerBar> {
  late final StreamSubscription<PlaybackError> _errors;

  @override
  void initState() {
    super.initState();
    _errors = ref
        .read(playerServiceProvider.notifier)
        .errors
        .listen(_showError);
  }

  void _showError(PlaybackError error) {
    if (!mounted) return;
    // A folder of unreachable files fails one track after another; show
    // only the latest instead of queuing them all.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.playerPlaybackError(error.track.title)),
        ),
      );
  }

  @override
  void dispose() {
    _errors.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < _compactBreakpoint;
        final tooltips = TooltipTheme.of(context);
        return SizedBox(
          height: playerBarHeight,
          child: TooltipTheme(
            data: tooltips.copyWith(verticalOffset: _tooltipOffset),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: NowPlayingSummary(
                          showCover: width >= _coverBreakpoint,
                        ),
                      ),
                      PlaybackControls(compact: compact),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          spacing: 8,
                          children: [
                            if (width >= _timeBreakpoint)
                              const Flexible(child: _TimeLabel()),
                            const VolumeButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Positioned(left: 0, right: 0, top: 0, child: SeekStrip()),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// `position / duration`, rebuilt on its own as the position ticks.
class _TimeLabel extends ConsumerWidget {
  const _TimeLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (position, duration, empty) = ref.watch(
      playerServiceProvider.select(
        (s) => (s.position, s.duration, s.queue.isEmpty),
      ),
    );
    if (empty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Text(
      '${formatDuration(position)} / ${formatDuration(duration)}',
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
