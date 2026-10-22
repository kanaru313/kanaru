import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../playback_controls.dart';

/// Top of the queue panel: title and track count on the left; on the right
/// icon buttons to clear the queue, scroll to the playing track and, in the
/// side sheet, close it.
class QueuePanelHeader extends StatelessWidget {
  const QueuePanelHeader({
    super.key,
    required this.trackCount,
    required this.onClear,
    required this.onShowCurrent,
    this.onClose,
  });

  final int trackCount;

  /// `null` greys the button out: nothing left to clear.
  final VoidCallback? onClear;
  final VoidCallback onShowCurrent;

  /// `null` hides the close button (the narrow page has nothing to close).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              spacing: 12,
              children: [
                Flexible(
                  child: Text(
                    l10n.queueTitle,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Flexible(
                  child: Text(
                    l10n.queueTrackCount(trackCount),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // The playing track stays, so clearing needs no confirmation.
          IconButton(
            icon: const Icon(AppIcons.clearAll),
            iconSize: playerIconSize,
            tooltip: l10n.queueClear,
            onPressed: onClear,
          ),
          IconButton(
            icon: const Icon(AppIcons.locateCurrent),
            iconSize: playerIconSize,
            tooltip: l10n.queueShowCurrent,
            onPressed: onShowCurrent,
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(AppIcons.closeRounded),
              iconSize: playerIconSize,
              tooltip: l10n.queueClose,
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}
