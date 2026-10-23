import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/queue_history_queries.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/library_loading.dart';
import '../../shared/widgets/menu_keyboard_region.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/playlist_cover.dart';
import '../../shared/widgets/queue_actions_menu.dart' show menuPositionAt;
import 'playlist_screen_states.dart';
import 'queue_history_actions.dart';
import 'queue_history_providers.dart';
import 'queue_history_routes.dart';

final _log = Logger('queue_history');

/// Height of one saved queue row.
const queueSnapshotRowExtent = 80.0;

/// `/queue-history`: the queues the user replaced, newest first. A row opens
/// the saved queue; its menu plays, shuffles, queues, saves or deletes it.
class QueueHistoryScreen extends ConsumerWidget {
  const QueueHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (ref.watch(libraryDatabaseProvider) == null) {
      return const PlaylistsUnavailable();
    }
    ref.listen(queueSnapshotsProvider, (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        _log.severe(
          'Reading the queue history failed',
          next.error,
          next.stackTrace,
        );
      }
    });

    return PageScaffold(
      title: l10n.queueHistoryTitle,
      body: ref
          .watch(queueSnapshotsProvider)
          .when(
            skipLoadingOnReload: true,
            skipError: true,
            loading: () => const LibraryLoading(),
            error: (error, stack) => EmptyState(
              icon: AppIcons.errorOutline,
              title: l10n.libraryUnavailableTitle,
              message: l10n.libraryUnavailableMessage,
            ),
            data: (snapshots) => snapshots.isEmpty
                ? EmptyState(
                    icon: AppIcons.history,
                    title: l10n.queueHistoryEmptyTitle,
                    message: l10n.queueHistoryEmptyMessage,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemExtent: queueSnapshotRowExtent,
                    itemCount: snapshots.length,
                    itemBuilder: (context, index) => QueueSnapshotRow(
                      key: ValueKey(snapshots[index].id),
                      snapshot: snapshots[index],
                    ),
                  ),
          ),
    );
  }
}

/// One saved queue: collage, when it was saved and its song count, a play
/// button and the menu (also on a right click, a long press or the menu
/// key). Tapping opens its page.
class QueueSnapshotRow extends ConsumerWidget {
  const QueueSnapshotRow({super.key, required this.snapshot});

  final QueueSnapshotCard snapshot;

  void _run(WidgetRef ref, BuildContext context, QueueSnapshotAction action) =>
      runQueueSnapshotAction(
        ref,
        context,
        action,
        id: snapshot.id,
        savedAt: snapshot.savedAt,
      );

  Future<void> _openMenu(
    WidgetRef ref,
    BuildContext context,
    Offset position,
  ) async {
    final action = await showMenu<QueueSnapshotAction>(
      context: context,
      position: menuPositionAt(context, position),
      items: queueSnapshotMenuItems(context),
    );
    if (action != null && context.mounted) _run(ref, context, action);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final row = Row(
      children: [
        PlaylistCover(
          coverKeys: snapshot.coverKeys,
          size: 56,
          seed: 'queue:${snapshot.id}',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                queueSnapshotName(l10n, snapshot.savedAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                l10n.playlistTrackCount(snapshot.trackCount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(AppIcons.play),
          tooltip: l10n.queueHistoryPlay,
          onPressed: () => _run(ref, context, QueueSnapshotAction.play),
        ),
        PopupMenuButton<QueueSnapshotAction>(
          tooltip: l10n.queueActionsTooltip,
          icon: const Icon(AppIcons.more),
          onSelected: (action) => _run(ref, context, action),
          itemBuilder: queueSnapshotMenuItems,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: MenuKeyboardRegion(
        onOpen: (position) => _openMenu(ref, context, position),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapUp: (d) => _openMenu(ref, context, d.globalPosition),
          onLongPressStart: (d) => _openMenu(ref, context, d.globalPosition),
          child: Material(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go(queueHistoryLocation(snapshot.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: row,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
