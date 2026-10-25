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
import '../../shared/widgets/page_scaffold.dart';
import 'collage_list_row.dart';
import 'playlist_screen_states.dart';
import 'queue_history_actions.dart';
import 'queue_history_providers.dart';
import 'queue_history_routes.dart';

final _log = Logger('queue_history');

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
                    itemExtent: collageListRowExtent,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    void run(QueueSnapshotAction action) => runQueueSnapshotAction(
      ref,
      context,
      action,
      id: snapshot.id,
      savedAt: snapshot.savedAt,
    );

    return CollageListRow<QueueSnapshotAction>(
      coverKeys: snapshot.coverKeys,
      seed: 'queue:${snapshot.id}',
      title: queueSnapshotName(l10n, snapshot.savedAt),
      subtitle: l10n.playlistTrackCount(snapshot.trackCount),
      onTap: () => context.go(queueHistoryLocation(snapshot.id)),
      onPlay: () => run(QueueSnapshotAction.play),
      playTooltip: l10n.queueHistoryPlay,
      menuItems: queueSnapshotMenuItems,
      onMenuSelected: run,
    );
  }
}
