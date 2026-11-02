import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import '../../../shared/widgets/queue_modal_footer.dart';
import 'playlist_modal_actions.dart';
import 'playlist_modal_advanced_page.dart';
import 'playlist_modal_data.dart';
import 'playlist_modal_header.dart';
import 'playlist_modal_session.dart';

/// The first page of the playlist modal: header, the play and copy actions,
/// Edit and Delete, and the queue buttons in the footer. The head and the
/// counts load while it is open; until then the rows that act are greyed out.
/// No dividers: the groups are told apart by a gap.
ContextModalPage playlistModalActionsPage(PlaylistModalSession session) {
  PlaylistModalData dataOf(WidgetRef ref) => watchPlaylistModalData(
    ref,
    snapshot: session.playlist,
    snapshotCoverKeys: session.coverKeys,
    showGoTo: session.showGoTo,
  );
  PlaylistModalHandlers handlersOf(
    BuildContext context,
    PlaylistModalData data,
  ) => session.handlers(
    latest: data.playlist,
    latestCoverKeys: data.coverKeys,
    // The modal route's own messenger, not the opener's.
    modalMessenger: ScaffoldMessenger.maybeOf(context),
    openAdvanced: (nav) => nav.push(playlistModalAdvancedPage(session)),
  );
  return ContextModalPage(
    key: 'playlist-actions',
    headerBuilder: (context, nav) => Consumer(
      builder: (context, ref, _) {
        final data = dataOf(ref);
        final handlers = handlersOf(context, data);
        return PlaylistModalHeader(
          playlist: data.playlist,
          coverKeys: data.coverKeys,
          onTap: session.showGoTo && !data.gone
              ? () => contextModalCloseThen(handlers.goToPlaylist)(nav)
              : null,
          onEdit: data.isFavorites || data.gone ? null : handlers.edit,
        );
      },
    ),
    bodyBuilder: (context, nav) => [
      Consumer(
        builder: (context, ref, _) {
          final data = dataOf(ref);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(
              nav,
              playlistModalSections(
                context.l10n,
                data,
                handlersOf(context, data),
              ),
              dividers: false,
            ),
          );
        },
      ),
    ],
    footerBuilder: (context, nav) => Consumer(
      builder: (context, ref, _) {
        final data = dataOf(ref);
        return QueueModalFooter(
          nav: nav,
          onAction: (action) => session.queue(action, data.playlist),
          keyPrefix: 'playlist-modal',
          divider: false,
          enabled: data.hasPlayable,
        );
      },
    ),
  );
}
