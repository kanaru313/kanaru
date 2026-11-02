import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/track_links_provider.dart';
import '../../l10n/l10n.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/queue_modal_footer.dart';
import 'song_modal_data.dart';
import 'song_modal_actions.dart';
import 'song_modal_advanced_page.dart';
import 'info/song_info_page.dart';
import 'song_modal_header.dart';
import 'song_modal_session.dart';

/// The first page of the song modal: header, the links and song actions, and
/// the queue buttons in the footer. Favorite and links load while it is
/// open; until then their rows are greyed out.
ContextModalPage songModalActionsPage(SongModalSession session) {
  return ContextModalPage(
    key: 'song-actions',
    headerBuilder: (context, nav) => SongModalHeader(
      song: session.song,
      note: session.headerNote,
      onTap: () => nav.push(songInfoPage(session)),
    ),
    bodyBuilder: (context, nav) => [
      Consumer(
        builder: (context, ref, _) {
          final hasLibrary = ref.watch(libraryDatabaseProvider) != null;
          final data = SongModalData(
            song: session.song,
            links: ref
                .watch(trackModalLinksProvider(session.song.id))
                .asData
                ?.value,
            isFavorite: ref
                .watch(songModalIsFavoriteProvider(session.song.path))
                .asData
                ?.value,
            hasLibrary: hasLibrary,
            canFindLyrics: session.lyricsTarget != null,
            showAlbum: session.showAlbum,
            pageArtistKey: session.pageArtistKey,
            showFolder: session.showFolder,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(
              nav,
              songModalSections(
                context.l10n,
                data,
                session.handlers(
                  openAdvanced: (nav) => nav.push(
                    songModalAdvancedPage(session, hasLibrary: hasLibrary),
                  ),
                ),
                extra: session.extraActions,
              ),
            ),
          );
        },
      ),
    ],
    footerBuilder: (context, nav) => QueueModalFooter(
      nav: nav,
      onAction: session.queue,
      keyPrefix: 'song-modal',
    ),
  );
}
