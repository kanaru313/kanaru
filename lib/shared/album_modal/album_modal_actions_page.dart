import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/album_links_provider.dart';
import '../../l10n/l10n.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/queue_modal_footer.dart';
import 'album_modal_actions.dart';
import 'album_modal_advanced_page.dart';
import 'album_modal_data.dart';
import 'album_modal_header.dart';
import 'album_modal_session.dart';
import 'album_modal_sub_pages.dart';

/// The first page of the album modal: header, the links and album actions,
/// and the queue buttons in the footer. The artists and folders load while it
/// is open; until then their rows are greyed out. No dividers: the groups are
/// told apart by a gap.
ContextModalPage albumModalActionsPage(AlbumModalSession session) {
  Widget header(AlbumModalSession s) => Consumer(
    builder: (context, ref, _) => AlbumModalHeader(
      album: s.album,
      summary: ref
          .watch(albumModalLinksProvider(s.album.key))
          .asData
          ?.value
          ?.summary,
    ),
  );
  return ContextModalPage(
    key: 'album-actions',
    headerBuilder: (context, nav) => header(session),
    bodyBuilder: (context, nav) => [
      Consumer(
        builder: (context, ref, _) {
          final links = ref
              .watch(albumModalLinksProvider(session.album.key))
              .asData
              ?.value;
          final data = AlbumModalData(
            album: session.album,
            links: links,
            showAlbum: session.showAlbum,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(
              nav,
              albumModalSections(
                context.l10n,
                data,
                session.handlers(
                  // The pages get the loaded lists: this page is unmounted
                  // while they show, which would drop the provider.
                  openArtists: (nav) => nav.push(
                    albumModalArtistsPage(session, links?.artists ?? const []),
                  ),
                  openFolders: (nav) => nav.push(
                    albumModalFoldersPage(session, links?.folders ?? const []),
                  ),
                  openAdvanced: (nav) =>
                      nav.push(albumModalAdvancedPage(session)),
                ),
              ),
              dividers: false,
            ),
          );
        },
      ),
    ],
    footerBuilder: (context, nav) => QueueModalFooter(
      nav: nav,
      onAction: session.queue,
      keyPrefix: 'album-modal',
      divider: false,
    ),
  );
}
