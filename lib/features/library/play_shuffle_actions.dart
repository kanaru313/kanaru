import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/queue_actions_menu.dart';

/// Room the labelled buttons need; with less, Shuffle shrinks to an icon.
const _labelledButtonsWidth = 320.0;

/// The buttons under an album or artist title: Play, Shuffle and the queue
/// menu. Shuffle is icon-only when the header text column is narrow.
class PlayShuffleActions extends StatelessWidget {
  const PlayShuffleActions({
    super.key,
    required this.playLabel,
    required this.onPlay,
    required this.onShuffle,
    required this.onQueueAction,
  });

  final String playLabel;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final ValueChanged<QueueAction> onQueueAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _labelledButtonsWidth;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(AppIcons.play),
              label: Text(playLabel),
            ),
            const SizedBox(width: 8),
            if (compact)
              IconButton.filledTonal(
                tooltip: l10n.libraryShuffle,
                icon: const Icon(AppIcons.shuffle),
                onPressed: onShuffle,
              )
            else
              FilledButton.tonalIcon(
                onPressed: onShuffle,
                icon: const Icon(AppIcons.shuffle),
                label: Text(l10n.libraryShuffle),
              ),
            const SizedBox(width: 4),
            QueueActionsButton(onSelected: onQueueAction),
          ],
        );
      },
    );
  }
}
