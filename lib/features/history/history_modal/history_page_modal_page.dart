import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import '../../../shared/widgets/queue_modal_footer.dart';
import '../history_providers.dart';
import 'history_page_modal_actions.dart';
import 'history_page_modal_header.dart';
import 'history_page_modal_session.dart';

/// The first page of the History modal: header, the actions and the queue
/// buttons. The totals are watched, so the header and the enabled rows follow
/// a play recorded while the modal is open.
ContextModalPage historyPageModalActionsPage(HistoryPageModalSession session) =>
    ContextModalPage(
      key: 'history-page-actions',
      headerBuilder: (context, nav) => Consumer(
        builder: (context, ref, _) => HistoryPageModalHeader(
          overview: ref.watch(historyOverviewProvider).value,
        ),
      ),
      bodyBuilder: (context, nav) => [
        Consumer(
          builder: (context, ref, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(
              nav,
              historyPageModalSections(
                context.l10n,
                ref.watch(historyOverviewProvider).value,
                session.handlers(
                  plays: ref.watch(historyOverviewProvider).value?.plays ?? 0,
                  openAdvanced: (nav) =>
                      nav.push(historyPageModalAdvancedPage(session)),
                ),
              ),
            ),
          ),
        ),
      ],
      footerBuilder: (context, nav) => Consumer(
        builder: (context, ref, _) {
          final overview = ref.watch(historyOverviewProvider).value;
          return QueueModalFooter(
            nav: nav,
            onAction: session.queue,
            keyPrefix: 'history-page-modal',
            enabled: overview != null && overview.plays > 0,
          );
        },
      ),
    );

/// The Advanced page: the two M3U exports and Clear history.
ContextModalPage historyPageModalAdvancedPage(
  HistoryPageModalSession session,
) => ContextModalPage(
  key: 'history-page-advanced',
  headerBuilder: (context, nav) => ContextModalTopBar(
    title: context.l10n.songModalAdvanced,
    onBack: nav.pop,
  ),
  bodyBuilder: (context, nav) => [
    Consumer(
      builder: (context, ref, _) {
        final overview = ref.watch(historyOverviewProvider).value;
        // Rebuilt when a clear starts or ends, from here or from Settings.
        return ValueListenableBuilder<bool>(
          valueListenable: session.clearing,
          builder: (context, clearing, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(
              nav,
              historyPageModalAdvancedSections(
                context.l10n,
                overview,
                session.handlers(plays: overview?.plays ?? 0),
                clearing: clearing,
              ),
            ),
          ),
        );
      },
    ),
  ],
);
