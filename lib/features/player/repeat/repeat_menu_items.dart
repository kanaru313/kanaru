import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../../core/player/player_service.dart';
import '../../../core/player/repeat_mode.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'repeat_labels.dart';
import 'repeat_mode_icon.dart';

/// Items of the repeat menu: stop at the end, repeat the song, repeat it N
/// more times (with - and + beside it), repeat the queue, repeat it shuffled.
///
/// [base] and [times] are the player's; [draft] is the number the counted
/// item arms with while no count runs, changed through [onDraft]. [stopped]
/// disables the counted item: arming it there would be dropped by the restart.
List<Widget> repeatMenuItems(
  BuildContext context,
  WidgetRef ref, {
  required RepeatMode base,
  required int times,
  required bool stopped,
  required int draft,
  required ValueChanged<int> onDraft,
}) {
  final l10n = context.l10n;
  final scheme = Theme.of(context).colorScheme;
  final player = ref.read(playerServiceProvider.notifier);
  final counting = isCounting(times);
  final shown = counting ? times : draft;

  Widget item(
    RepeatMode mode,
    VoidCallback onPressed, {
    bool counted = false,
    bool enabled = true,
  }) {
    final active = counted ? counting : !counting && base == mode;
    return Semantics(
      selected: active,
      child: MenuItemButton(
        style: active
            ? MenuItemButton.styleFrom(
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
              )
            : null,
        leadingIcon: RepeatModeIcon(
          mode: mode,
          counted: counted,
          times: shown,
          size: 24,
          menu: true,
        ),
        onPressed: enabled ? onPressed : null,
        child: Text(
          repeatModeLabel(l10n, mode, counted: counted, times: shown),
        ),
      ),
    );
  }

  void step(int delta) {
    final next = (shown + delta).clamp(1, maxRepeatTimes);
    if (counting) {
      player.setRepeatTimes(next);
    } else {
      onDraft(next);
    }
  }

  return [
    item(RepeatMode.off, () => player.setRepeat(RepeatMode.off)),
    item(RepeatMode.one, () => player.setRepeat(RepeatMode.one)),
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: item(
            base,
            () => player.setRepeatTimes(shown),
            counted: true,
            enabled: !stopped,
          ),
        ),
        IconButton(
          icon: const Icon(AppIcons.remove),
          tooltip: l10n.playerRepeatFewer,
          onPressed: stopped || shown <= 1 ? null : () => step(-1),
        ),
        IconButton(
          icon: const Icon(AppIcons.add),
          tooltip: l10n.playerRepeatMore,
          onPressed: stopped || shown >= maxRepeatTimes ? null : () => step(1),
        ),
      ],
    ),
    item(RepeatMode.all, () => player.setRepeat(RepeatMode.all)),
    item(
      RepeatMode.allShuffled,
      () => player.setRepeat(RepeatMode.allShuffled),
    ),
  ];
}
