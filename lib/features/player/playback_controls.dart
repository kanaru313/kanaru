import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../core/player/player_service.dart';
import '../../core/player/repeat_mode.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

/// Icon size of the player bar's buttons; play/pause is larger.
const playerIconSize = 28.0;

/// Shuffle · previous · play/pause · next · repeat. Disabled while the
/// queue is empty; previous and next also on the first and last track
/// unless the queue repeats or the endless queue setting is on.
class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({
    super.key,
    this.compact = false,
    this.transportOnly = false,
    this.spread = false,
    this.spacing = 4,
  }) : assert(
         !(compact && transportOnly),
         'compact and transportOnly are exclusive',
       );

  /// Only play/pause and next, for narrow windows; the rest stays on the
  /// keyboard.
  final bool compact;

  /// Only previous, play/pause and next: no shuffle and repeat.
  final bool transportOnly;

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
    final (empty, playing) = ref.watch(
      playerServiceProvider.select((s) => (s.queue.isEmpty, s.playing)),
    );
    final wrap = ref.watch(
      settingsProvider.select((s) => s.playback.infiniteQueue),
    );
    final (hasPrevious, hasNext) = ref.watch(
      playerServiceProvider.select(
        (s) => (
          s.queue.manualPreviousIndex(wrap: wrap) != null,
          s.queue.manualNextIndex(wrap: wrap) != null,
        ),
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
        if (!compact && !transportOnly) ShuffleButton(iconSize: modeSize),
        if (!compact)
          IconButton(
            icon: const Icon(AppIcons.skipPrevious),
            iconSize: skipSize,
            tooltip: l10n.playerPrevious,
            onPressed: hasPrevious ? player.previous : null,
          ),
        IconButton.filledTonal(
          icon: Icon(playing ? AppIcons.pause : AppIcons.playRounded),
          iconSize: spread ? 40 : 36,
          style: spread
              ? IconButton.styleFrom(minimumSize: const Size.square(60))
              : null,
          tooltip: playing ? l10n.playerPause : l10n.playerPlay,
          onPressed: when(player.playPause),
        ),
        IconButton(
          icon: const Icon(AppIcons.skipNext),
          iconSize: skipSize,
          tooltip: l10n.playerNext,
          onPressed: hasNext ? player.next : null,
        ),
        if (!compact && !transportOnly) RepeatButton(iconSize: modeSize),
      ],
    );
  }
}

/// The shuffle toggle; disabled while the queue is empty.
class ShuffleButton extends ConsumerWidget {
  const ShuffleButton({super.key, this.iconSize = playerIconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (empty, shuffled) = ref.watch(
      playerServiceProvider.select((s) => (s.queue.isEmpty, s.queue.shuffled)),
    );
    return IconButton(
      icon: const Icon(AppIcons.shuffle),
      iconSize: iconSize,
      tooltip: context.l10n.playerShuffle,
      isSelected: shuffled,
      onPressed: empty
          ? null
          : ref.read(playerServiceProvider.notifier).toggleShuffle,
    );
  }
}

/// The repeat cycle (off, all, one); disabled while the queue is empty.
class RepeatButton extends ConsumerWidget {
  const RepeatButton({super.key, this.iconSize = playerIconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (empty, repeat) = ref.watch(
      playerServiceProvider.select((s) => (s.queue.isEmpty, s.queue.repeat)),
    );
    return IconButton(
      icon: Icon(
        repeat == RepeatMode.one ? AppIcons.repeatOne : AppIcons.repeat,
      ),
      iconSize: iconSize,
      tooltip: switch (repeat) {
        RepeatMode.off => l10n.playerRepeatOff,
        RepeatMode.all => l10n.playerRepeatAll,
        RepeatMode.one => l10n.playerRepeatOne,
      },
      isSelected: repeat != RepeatMode.off,
      onPressed: empty
          ? null
          : ref.read(playerServiceProvider.notifier).cycleRepeat,
    );
  }
}
