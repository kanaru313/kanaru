import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'queue_row_extent.dart';

/// A section title ("Play next (2)", "Up next") over a row-wide slot of
/// [height] (`queueSectionLabelExtent` unless given), the text sitting at the
/// bottom edge.
class QueueSectionLabel extends StatelessWidget {
  const QueueSectionLabel({super.key, required this.text, this.height});

  final String text;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The text is the header; the visual copy is not read twice.
    return Semantics(
      header: true,
      label: text,
      excludeSemantics: true,
      child: SizedBox(
        height: height ?? queueSectionLabelExtent(context),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The row right above the playing track that shows or hides the tracks
/// before it. Enter toggles it (it is focusable); Space stays play/pause
/// app-wide.
class QueueEarlierToggle extends StatelessWidget {
  const QueueEarlierToggle({
    super.key,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final label = l10n.queueSectionEarlier(count);
    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      hint: expanded ? l10n.queueHideEarlier : l10n.queueShowEarlier,
      // The visible row is folded into this node, so it carries the tap
      // action the row's InkWell would otherwise expose.
      onTap: onToggle,
      excludeSemantics: true,
      child: SizedBox(
        height: queueSectionLabelExtent(context),
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  expanded ? AppIcons.expandLess : AppIcons.expandMore,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Last row of the list while repeating the whole queue: the tracks that
/// wrap around are the earlier ones above, so say where the queue goes next.
class QueueRepeatsFromStartRow extends StatelessWidget {
  const QueueRepeatsFromStartRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: queueRowExtent(context),
      child: Center(
        child: Text(
          context.l10n.queueRepeatsFromStart,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
