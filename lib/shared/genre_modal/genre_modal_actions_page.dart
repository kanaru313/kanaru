import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/queue_modal_footer.dart';
import 'genre_modal_actions.dart';
import 'genre_modal_advanced_page.dart';
import 'genre_modal_data.dart';
import 'genre_modal_header.dart';
import 'genre_modal_links.dart';
import 'genre_modal_session.dart';
import 'genre_modal_sub_pages.dart';

/// The first page of the genre modal: header, the links and genre actions,
/// and the queue buttons in the footer. The albums and folders load while it
/// is open; until then their rows are greyed out. Once read and gone (no song
/// has the genre any more) the play and copy rows and the footer are
/// greyed out too. No dividers: the groups are told apart by a gap.
///
/// The links are read with `.asData?.value`: while the library keys are
/// rewritten the provider rebuilds and the rows grey out until it has read
/// again. Only a resolved null counts as gone, so loading keeps Play all
/// enabled (keyboard focus may land on it).
ContextModalPage genreModalActionsPage(GenreModalSession session) {
  AsyncValue<GenreLinks?> linksOf(WidgetRef ref) =>
      ref.watch(genreModalLinksProvider(session.genre));
  return ContextModalPage(
    key: 'genre-actions',
    headerBuilder: (context, nav) => Consumer(
      builder: (context, ref, _) {
        final data = GenreModalData(
          genre: session.genre,
          links: linksOf(ref).asData?.value,
          showGenre: session.showGenre,
        );
        final goToGenre = contextModalCloseThen(session.handlers().goToGenre);
        return GenreModalHeader(
          genre: session.genre,
          displayName: data.displayName(context.l10n),
          albumCount: data.albumCount,
          durationMs: data.durationMs,
          onTap: session.showGenre ? () => goToGenre(nav) : null,
        );
      },
    ),
    bodyBuilder: (context, nav) => [
      Consumer(
        builder: (context, ref, _) {
          final async = linksOf(ref);
          final links = async.asData?.value;
          final data = GenreModalData(
            genre: session.genre,
            links: links,
            showGenre: session.showGenre,
            gone: GenreModalData.goneOf(async),
          );
          final displayName = data.displayName(context.l10n);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(
              nav,
              genreModalSections(
                context.l10n,
                data,
                session.handlers(
                  openAlbums: (nav) => nav.push(
                    genreModalAlbumsPage(
                      session,
                      links?.albums ?? const [],
                    ),
                  ),
                  openFolders: (nav) => nav.push(
                    genreModalFoldersPage(
                      session,
                      links?.folders ?? const [],
                      displayName,
                    ),
                  ),
                  openAdvanced: (nav) =>
                      nav.push(genreModalAdvancedPage(session)),
                ),
              ),
            ),
          );
        },
      ),
    ],
    // The footer builder has no ref: a Consumer greys it out when gone.
    footerBuilder: (context, nav) => Consumer(
      builder: (context, ref, _) => QueueModalFooter(
        nav: nav,
        onAction: session.queue,
        keyPrefix: 'genre-modal',
        enabled: !GenreModalData.goneOf(linksOf(ref)),
      ),
    ),
  );
}
