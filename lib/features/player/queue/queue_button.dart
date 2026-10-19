import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../l10n/l10n.dart';
import '../playback_controls.dart';

/// Largest count the badge shows; more reads as `9999+`.
const _badgeMax = 9999;

/// Queue icon with the number of tracks queued. Opens the end drawer of the
/// nearest [Scaffold], where the queue panel lives.
class QueueButton extends ConsumerWidget {
  const QueueButton({super.key, this.onPressed});

  /// Replaces opening the drawer, e.g. to switch to a queue page instead.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      playerServiceProvider.select((s) => s.queue.order.length),
    );
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > _badgeMax ? '$_badgeMax+' : '$count'),
      child: IconButton(
        icon: const Icon(Icons.queue_music_rounded),
        iconSize: playerIconSize,
        tooltip: context.l10n.queueOpen,
        onPressed: count == 0
            ? null
            : onPressed ?? Scaffold.of(context).openEndDrawer,
      ),
    );
  }
}
