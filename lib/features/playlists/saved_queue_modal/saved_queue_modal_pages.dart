import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import '../../../shared/widgets/queue_modal_footer.dart';
import 'saved_queue_modal_actions.dart';
import 'saved_queue_modal_data.dart';
import 'saved_queue_modal_header.dart';
import 'saved_queue_modal_session.dart';

SavedQueueModalData _dataOf(SavedQueueModalSession session, WidgetRef ref) =>
    watchSavedQueueModalData(
      ref,
      snapshot: session.playlist,
      snapshotCoverKeys: session.coverKeys,
      showGoTo: session.showGoTo,
      l10n: session.runner.l10n,
    );

/// The first page of the saved-queue modal: header, the play and copy
/// actions, Delete queue, and the queue buttons in the footer. The head and
/// the counts load while it is open; until then the rows that act are greyed
/// out. No dividers: the groups are told apart by a gap.
ContextModalPage savedQueueModalActionsPage(SavedQueueModalSession session) {
  SavedQueueModalHandlers handlersOf(SavedQueueModalData data) =>
      session.handlers(
        latest: data.playlist,
        openAdvanced: (nav) => nav.push(savedQueueModalAdvancedPage(session)),
      );
  return ContextModalPage(
    key: 'saved-queue-actions',
    headerBuilder: (context, nav) => Consumer(
      builder: (context, ref, _) {
        final data = _dataOf(session, ref);
        final handlers = handlersOf(data);
        return SavedQueueModalHeader(
          playlist: data.playlist,
          coverKeys: data.coverKeys,
          stats: data.stats,
          onTap: session.showGoTo && !data.gone
              ? () => contextModalCloseThen(handlers.goToQueue)(nav)
              : null,
        );
      },
    ),
    bodyBuilder: (context, nav) => [
      Consumer(
        builder: (context, ref, _) {
          final data = _dataOf(session, ref);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(
              nav,
              savedQueueModalSections(context.l10n, data, handlersOf(data)),
            ),
          );
        },
      ),
    ],
    footerBuilder: (context, nav) => Consumer(
      builder: (context, ref, _) {
        final data = _dataOf(session, ref);
        return QueueModalFooter(
          nav: nav,
          onAction: (action) => session.queue(action, data.playlist),
          keyPrefix: 'saved-queue-modal',
          enabled: data.hasPlayable,
        );
      },
    ),
  );
}

/// The Advanced page: Add all to Favorites, the M3U exports and Remove
/// missing songs. Header and body watch the head and the counts themselves,
/// which keeps them alive while this page covers the first one.
ContextModalPage savedQueueModalAdvancedPage(SavedQueueModalSession session) =>
    ContextModalPage(
      key: 'saved-queue-advanced',
      headerBuilder: (context, nav) => Consumer(
        builder: (context, ref, _) {
          _dataOf(session, ref);
          return ContextModalTopBar(
            title: context.l10n.songModalAdvanced,
            onBack: nav.pop,
          );
        },
      ),
      bodyBuilder: (context, nav) => [
        Consumer(
          builder: (context, ref, _) {
            final data = _dataOf(session, ref);
            final handlers = session.handlers(latest: data.playlist);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: contextModalSections(
                nav,
                savedQueueModalAdvancedSections(context.l10n, data, handlers),
              ),
            );
          },
        ),
      ],
    );
