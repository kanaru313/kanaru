import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../core/player/player_service.dart';
import '../../core/player/repeat_mode.dart';
import '../../l10n/l10n.dart';

/// Icon size of the player bar's buttons; play/pause is larger.
const playerIconSize = 28.0;

/// Shuffle · previous · play/pause · next · repeat. Disabled while the
/// queue is empty; previous and next also on the first and last track
/// unless the queue repeats.
class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({
    super.key,
    this.compact = false,
    this.spread = false,
    this.spacing = 4,
  });

  /// Only play/pause and next, for narrow windows; the rest stays on the
  /// keyboard.
  final bool compact;

  /// Fills the width with the buttons spaced out, and bigger: shuffle and
  /// repeat 24, previous and next 36, play/pause 40 in a 60 circle. For the
  /// narrow Now Playing page, where the row is the main control.
  final bool spread;

  /// Gap between buttons when not [spread]: tight in the player bar, roomier
  /// in the Now Playing footer.
  final double spacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (empty, playing, shuffled, repeat) = ref.watch(
      playerServiceProvider.select(
        (s) => (s.queue.isEmpty, s.playing, s.queue.shuffled, s.queue.repeat),
      ),
    );
    final (hasPrevious, hasNext) = ref.watch(
      playerServiceProvider.select(
        (s) => (s.queue.previousIndex != null, s.queue.nextIndex != null),
      ),
    );
    final player = ref.read(playerServiceProvider.notifier);
    VoidCallback? when(VoidCallback action) => empty ? null : action;
    final modeSize = spread ? 24.0 : playerIconSize;
    final skipSize = spread ? 36.0 : playerIconSize;

    return Row(
      mainAxisSize: spread ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: spread
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.start,
      spacing: spread ? 0 : spacing,
      children: [
        if (!compact) ...[
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            iconSize: modeSize,
            tooltip: l10n.playerShuffle,
            isSelected: shuffled,
            onPressed: when(player.toggleShuffle),
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded),
            iconSize: skipSize,
            tooltip: l10n.playerPrevious,
            onPressed: hasPrevious ? player.previous : null,
          ),
        ],
        IconButton.filledTonal(
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          iconSize: spread ? 40 : 36,
          style: spread
              ? IconButton.styleFrom(minimumSize: const Size.square(60))
              : null,
          tooltip: playing ? l10n.playerPause : l10n.playerPlay,
          onPressed: when(player.playPause),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: skipSize,
          tooltip: l10n.playerNext,
          onPressed: hasNext ? player.next : null,
        ),
        if (!compact)
          IconButton(
            icon: Icon(
              repeat == RepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
            ),
            iconSize: modeSize,
            tooltip: switch (repeat) {
              RepeatMode.off => l10n.playerRepeatOff,
              RepeatMode.all => l10n.playerRepeatAll,
              RepeatMode.one => l10n.playerRepeatOne,
            },
            isSelected: repeat != RepeatMode.off,
            onPressed: when(player.cycleRepeat),
          ),
      ],
    );
  }
}
