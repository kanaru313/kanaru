import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import '../../../shared/widgets/queue_modal_footer.dart';
import 'history_day_modal_actions.dart';
import 'history_day_modal_header.dart';
import 'history_day_modal_session.dart';

/// The first page of the Day modal: header, the play and copy actions,
/// Remove, and the queue buttons in the footer. The snapshot is fixed, so
/// nothing here loads or watches.
ContextModalPage historyDayModalActionsPage(HistoryDayModalSession session) =>
    ContextModalPage(
      key: 'history-day-actions',
      headerBuilder: (context, nav) =>
          HistoryDayModalHeader(data: session.data, now: session.now),
      bodyBuilder: (context, nav) => [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: contextModalSections(
            nav,
            historyDayModalSections(
              context.l10n,
              session.data,
              session.handlers(
                openAdvanced: (nav) =>
                    nav.push(historyDayModalAdvancedPage(session)),
              ),
            ),
          ),
        ),
      ],
      footerBuilder: (context, nav) => QueueModalFooter(
        nav: nav,
        onAction: session.queue,
        keyPrefix: 'history-day-modal',
        enabled: session.data.canQueue,
      ),
    );

/// The Advanced page: Open in Most played and the two M3U exports.
ContextModalPage historyDayModalAdvancedPage(HistoryDayModalSession session) =>
    ContextModalPage(
      key: 'history-day-advanced',
      headerBuilder: (context, nav) => ContextModalTopBar(
        title: context.l10n.songModalAdvanced,
        onBack: nav.pop,
      ),
      bodyBuilder: (context, nav) => [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: contextModalSections(
            nav,
            historyDayModalAdvancedSections(
              context.l10n,
              session.data,
              session.handlers(),
            ),
          ),
        ),
      ],
    );
