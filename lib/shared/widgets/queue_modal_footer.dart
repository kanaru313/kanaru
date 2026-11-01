import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import 'context_modal/context_modal_nav.dart';
import 'queue_actions_menu.dart';

/// Play next and Add to queue: each closes the modal, then hands its action
/// to [onAction]. Keys are `<keyPrefix>-play-next` and
/// `<keyPrefix>-add-to-queue`. [divider] draws a line above the buttons.
class QueueModalFooter extends StatelessWidget {
  const QueueModalFooter({
    super.key,
    required this.nav,
    required this.onAction,
    required this.keyPrefix,
    this.divider = true,
  });

  final ContextModalNav nav;
  final ValueChanged<QueueAction> onAction;
  final String keyPrefix;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodyLarge;
    final color = Theme.of(context).colorScheme.primary;
    // The InkWell fills its whole half of the footer, so hover and ink cover
    // it all rather than a blob around the label.
    Widget button(Key key, IconData icon, String label, QueueAction action) =>
        Expanded(
          child: InkWell(
            key: key,
            onTap: () {
              nav.close();
              onAction(action);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  Icon(icon, size: 20, color: color),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: style?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (divider) const Divider(height: 1),
        Row(
          children: [
            button(
              ValueKey('$keyPrefix-play-next'),
              AppIcons.playlistPlay,
              l10n.queuePlayNext,
              QueueAction.playNext,
            ),
            button(
              ValueKey('$keyPrefix-add-to-queue'),
              AppIcons.addToQueue,
              l10n.queueAddToQueue,
              QueueAction.addToQueue,
            ),
          ],
        ),
      ],
    );
  }
}
