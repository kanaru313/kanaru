import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../icons/app_icons.dart';
import '../queue_actions_menu.dart';

/// Room the labelled buttons need; with less, Shuffle shrinks to an icon.
const _labelledButtonsWidth = 320.0;

/// The buttons under a detail page title (album, artist, genre, language,
/// playlist): Play, Shuffle and the queue menu. Shuffle is icon-only when the
/// header text column is narrow.
class PlayShuffleActions extends StatelessWidget {
  const PlayShuffleActions({
    super.key,
    required this.playLabel,
    required this.onPlay,
    required this.onShuffle,
    required this.onQueueAction,
  });

  final String playLabel;

  /// Null disables the Play button.
  final VoidCallback? onPlay;

  /// Null disables the Shuffle button.
  final VoidCallback? onShuffle;

  /// Null leaves the queue menu out.
  final ValueChanged<QueueAction>? onQueueAction;

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
            if (onQueueAction case final onQueueAction?) ...[
              const SizedBox(width: 4),
              QueueActionsButton(onSelected: onQueueAction),
            ],
          ],
        );
      },
    );
  }
}
