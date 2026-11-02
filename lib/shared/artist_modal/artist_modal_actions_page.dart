import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/queue_modal_footer.dart';
import 'artist_modal_actions.dart';
import 'artist_modal_advanced_page.dart';
import 'artist_modal_data.dart';
import 'artist_modal_header.dart';
import 'artist_modal_links.dart';
import 'artist_modal_session.dart';
import 'artist_modal_sub_pages.dart';

/// The first page of the artist modal: header, the links and artist actions,
/// and the queue buttons in the footer. The albums and folders load while it
/// is open; until then their rows are greyed out. Once read and gone (no song
/// credits the artist any more) the play and copy rows and the footer are
/// greyed out too. No dividers: the groups are told apart by a gap.
///
/// The links are read with `.asData?.value`, like the album modal: while the
/// library keys are rewritten the provider rebuilds and the rows grey out
/// until it has read again. Only a resolved null counts as gone, so loading
/// keeps Play all enabled (keyboard focus may land on it).
ContextModalPage artistModalActionsPage(ArtistModalSession session) {
  AsyncValue<ArtistLinks?> linksOf(WidgetRef ref) =>
      ref.watch(artistModalLinksProvider(session.artist.key));
  return ContextModalPage(
    key: 'artist-actions',
    headerBuilder: (context, nav) => Consumer(
      builder: (context, ref, _) {
        final data = ArtistModalData(
          artist: session.artist,
          links: linksOf(ref).asData?.value,
          showArtist: session.showArtist,
        );
        final goToArtist = contextModalCloseThen(session.handlers().goToArtist);
        return ArtistModalHeader(
          artist: session.artist,
          name: data.displayName,
          onTap: session.showArtist ? () => goToArtist(nav) : null,
        );
      },
    ),
    bodyBuilder: (context, nav) => [
      Consumer(
        builder: (context, ref, _) {
          final async = linksOf(ref);
          final links = async.asData?.value;
          final data = ArtistModalData(
            artist: session.artist,
            links: links,
            showArtist: session.showArtist,
            gone: ArtistModalData.goneOf(async),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(
              nav,
              artistModalSections(
                context.l10n,
                data,
                session.handlers(
                  // The pages get the loaded lists: this page is unmounted
                  // while they show, which would drop the provider.
                  openAlbums: (nav) => nav.push(
                    artistModalAlbumsPage(
                      session,
                      links?.sections.albums ?? const [],
                      links?.sections.appearsOn ?? const [],
                    ),
                  ),
                  openFolders: (nav) => nav.push(
                    artistModalFoldersPage(
                      session,
                      links?.folders ?? const [],
                      data.displayName,
                    ),
                  ),
                  openAdvanced: (nav) =>
                      nav.push(artistModalAdvancedPage(session)),
                ),
              ),
              dividers: false,
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
        keyPrefix: 'artist-modal',
        divider: false,
        enabled: !ArtistModalData.goneOf(linksOf(ref)),
      ),
    ),
  );
}
