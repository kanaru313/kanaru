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
  const PlaybackControls({super.key, this.compact = false});

  /// Leaves out shuffle and repeat on narrow windows.
  final bool compact;

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

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        if (!compact)
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            iconSize: playerIconSize,
            tooltip: l10n.playerShuffle,
            isSelected: shuffled,
            onPressed: when(player.toggleShuffle),
          ),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: playerIconSize,
          tooltip: l10n.playerPrevious,
          onPressed: hasPrevious ? player.previous : null,
        ),
        IconButton.filledTonal(
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          iconSize: 36,
          tooltip: playing ? l10n.playerPause : l10n.playerPlay,
          onPressed: when(player.playPause),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: playerIconSize,
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
            iconSize: playerIconSize,
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
