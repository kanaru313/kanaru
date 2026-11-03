import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/context_modal/context_modal_route.dart';
import 'playlist_modal_actions.dart';
import 'playlist_modal_data.dart';
import 'playlist_modal_session.dart';

/// The Advanced page: Add all to Favorites, Duplicate, the M3U exports and
/// the clean-ups. Header and body watch the head and the counts themselves,
/// which keeps them alive while this page covers the first one (the header
/// is not disposed when the body scrolls).
ContextModalPage playlistModalAdvancedPage(PlaylistModalSession session) {
  PlaylistModalData dataOf(WidgetRef ref) => watchPlaylistModalData(
    ref,
    snapshot: session.playlist,
    snapshotCoverKeys: session.coverKeys,
    showGoTo: session.showGoTo,
    savedQueue: session.savedQueue,
    queueL10n: session.l10n,
  );
  return ContextModalPage(
    key: 'playlist-advanced',
    headerBuilder: (context, nav) => Consumer(
      builder: (context, ref, _) {
        dataOf(ref);
        return ContextModalTopBar(
          title: context.l10n.songModalAdvanced,
          onBack: nav.pop,
        );
      },
    ),
    bodyBuilder: (context, nav) => [
      Consumer(
        builder: (context, ref, _) {
          final data = dataOf(ref);
          final handlers = session.handlers(
            latest: data.playlist,
            latestCoverKeys: data.coverKeys,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(
              nav,
              playlistModalAdvancedSections(context.l10n, data, handlers),
            ),
          );
        },
      ),
    ],
  );
}
