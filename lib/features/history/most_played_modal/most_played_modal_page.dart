import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import '../../../shared/widgets/queue_modal_footer.dart';
import 'most_played_modal_actions.dart';
import 'most_played_modal_header.dart';
import 'most_played_modal_session.dart';

/// The Most played modal's only page: header, the actions and the queue
/// buttons. The snapshot is fixed, so nothing here loads or watches.
ContextModalPage mostPlayedModalPage(MostPlayedModalSession session) =>
    ContextModalPage(
      key: 'most-played-actions',
      headerBuilder: (context, nav) => MostPlayedModalHeader(
        rangeText: session.rangeText,
        totals: session.totals,
      ),
      bodyBuilder: (context, nav) => [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: contextModalSections(
            nav,
            mostPlayedModalSections(
              context.l10n,
              session.rangeText,
              session.tracks.length,
              session.handlers(),
            ),
          ),
        ),
      ],
      footerBuilder: (context, nav) => QueueModalFooter(
        nav: nav,
        onAction: session.queue,
        keyPrefix: 'most-played-modal',
        enabled: session.canAct,
      ),
    );
