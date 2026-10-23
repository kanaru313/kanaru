import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../features/player/queue/queue_sheet_host.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'sidebar_item.dart';

/// The sidebar's "Current queue": opens the queue side sheet of the
/// enclosing [QueueSheetHost], or closes it, and is lit while it is open.
/// Disabled while nothing is queued (the sheet closes itself on an empty
/// queue) or outside a host.
class SidebarCurrentQueueItem extends ConsumerWidget {
  const SidebarCurrentQueueItem({
    super.key,
    required this.compact,
    this.onToggled,
  });

  final bool compact;

  /// Called after the sheet was asked to open or close.
  final VoidCallback? onToggled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = context.l10n.sidebarCurrentQueue;
    final empty = ref.watch(
      playerServiceProvider.select((s) => s.queue.isEmpty),
    );
    final sheet = QueueSheetHost.maybeOf(context);

    Widget item(bool open) => SidebarItem(
      icon: AppIcons.currentQueueOutlined,
      selectedIcon: AppIcons.currentQueue,
      label: label,
      selected: open,
      compact: compact,
      onTap: sheet == null || (empty && !open)
          ? null
          : () {
              open ? sheet.close() : sheet.open();
              onToggled?.call();
            },
    );

    if (sheet == null) return item(false);
    return ValueListenableBuilder<bool>(
      valueListenable: sheet.openListenable,
      builder: (context, open, _) => item(open),
    );
  }
}
