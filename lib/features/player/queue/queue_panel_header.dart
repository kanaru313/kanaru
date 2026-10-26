import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../playback_controls.dart';

/// Edges of the header row.
const queueHeaderPadding = EdgeInsets.fromLTRB(24, 16, 12, 8);

/// Space reserved for the four buttons (filter, save, clear, show-current)
/// that end the row, one 48 px touch target each.
const queueHeaderActionsWidth = 4 * 48.0;

/// Top of the queue panel: title and track count on the left; on the right
/// icon buttons to filter the queue, save the queue as a playlist, clear it,
/// scroll to the playing track and, in the side sheet, close it.
class QueuePanelHeader extends StatelessWidget {
  const QueuePanelHeader({
    super.key,
    required this.trackCount,
    required this.filterOpen,
    required this.onFilter,
    this.filterFocus,
    this.onSave,
    required this.onClear,
    required this.onShowCurrent,
    this.onClose,
    this.title,
  });

  final int trackCount;

  /// Whether the filter box is shown below the header.
  final bool filterOpen;

  /// Opens the filter box, or closes it when it is open.
  final VoidCallback onFilter;

  /// Focus of the filter button, so Esc in the box can return to it.
  final FocusNode? filterFocus;

  /// Saves the queue as a playlist; `null` greys the button out (no
  /// library).
  final VoidCallback? onSave;

  /// `null` greys the button out: nothing left to clear.
  final VoidCallback? onClear;
  final VoidCallback onShowCurrent;

  /// `null` hides the close button (the narrow page has nothing to close).
  final VoidCallback? onClose;

  /// Takes the place of the title and the track count, e.g. a tab bar; the
  /// buttons stay on its right.
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: queueHeaderPadding,
      child: Row(
        children: [
          Expanded(
            child:
                title ??
                Row(
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
          IconButton(
            focusNode: filterFocus,
            icon: const Icon(AppIcons.search),
            iconSize: playerIconSize,
            tooltip: l10n.inPageSearchOpen,
            isSelected: filterOpen,
            onPressed: onFilter,
          ),
          IconButton(
            icon: const Icon(AppIcons.saveQueue),
            iconSize: playerIconSize,
            tooltip: l10n.queueSaveAsPlaylist,
            onPressed: onSave,
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
