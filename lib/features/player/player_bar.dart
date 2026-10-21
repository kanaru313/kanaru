import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/playback_error.dart';
import '../../core/player/player_service.dart';
import '../../l10n/l10n.dart';
import 'now_playing_summary.dart';
import 'open_media.dart';
import 'playback_controls.dart';
import 'queue/queue_button.dart';
import 'seek_bar.dart';
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

/// Below this width the bar keeps only the track summary, play/pause and
/// next, with a thin seek strip on the top edge.
const _compactBreakpoint = 720.0;

/// Widest the controls and seek bar column gets.
const _centerMaxWidth = 640.0;

/// Width left to each side of that column at the least: the track summary
/// on the left, volume on the right.
const _sideMinWidth = 200.0;

/// Space between the bar's three parts.
const _gap = 8.0;

/// Gap between a button's center and its tooltip: half the play/pause
/// button plus some air, so the tooltip clears the hover highlight.
const _tooltipOffset = 34.0;

/// Full-width bar at the bottom of the window: track summary on the left,
/// playback controls over the seek bar in the middle, volume on the right.
/// Narrow windows keep the summary, play/pause and next, with a thin seek
/// strip on the top edge. Shows a snack bar for the latest track that
/// failed.
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
    // A position tick dirties the layout builders below. The fixed height
    // keeps their layout from reaching the scaffold. In the compact layout the
    // outer boundary keeps the repaint from the scaffold too; in the wide one
    // the repaint stops at the bar's inner layer, which is painted again.
    return RepaintBoundary(
      child: SizedBox(
        height: playerBarHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < _compactBreakpoint;
            final tooltips = TooltipTheme.of(context);
            return RepaintBoundary(
              child: TooltipTheme(
                data: tooltips.copyWith(verticalOffset: _tooltipOffset),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: compact ? const _CompactRow() : const _OneRow(),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: compact
                          ? const SeekStrip()
                          : const Divider(height: 1, thickness: 1),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OneRow extends StatelessWidget {
  const _OneRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Room for the summary and volume first. At the narrowest one-row
        // width the column still fits the controls.
        final center = (constraints.maxWidth - 2 * (_sideMinWidth + _gap))
            .clamp(0.0, _centerMaxWidth);
        // A tick dirties this builder; with a boundary under it, the title
        // and buttons were not painted again in the tests.
        return RepaintBoundary(
          child: Row(
            spacing: _gap,
            children: [
              const Expanded(child: NowPlayingSummary()),
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: center, maxWidth: center),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [PlaybackControls(), SeekBar()],
                ),
              ),
              const Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [VolumeButton(), QueueButton()],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      spacing: _gap,
      children: [
        Expanded(child: NowPlayingSummary()),
        PlaybackControls(compact: true),
      ],
    );
  }
}
