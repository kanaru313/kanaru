import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_browse_album_links.dart';
import '../../core/database/library_browse_rows.dart' show AlbumSummary;
import '../../l10n/l10n.dart';
import '../folder_links/folder_links_page.dart';
import '../genre_display_name.dart';
import '../icons/app_icons.dart';
import '../widgets/album_artwork.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/library_row.dart';
import 'genre_modal_data.dart';
import 'genre_modal_links.dart';
import 'genre_modal_session.dart';

/// Watches the genre's links so they stay alive while a sub page covers the
/// first page; draws [builder]. Sits in the page header, which (unlike a body
/// child) is not disposed when the body scrolls. Also gives [builder] the
/// loaded links, for the pages that show them, and whether the genre is
/// gone (read and found no song; false while loading).
class GenreLinksKeepAlive extends ConsumerWidget {
  const GenreLinksKeepAlive(this.session, {super.key, required this.builder});

  final GenreModalSession session;
  final Widget Function(BuildContext context, GenreLinks? links, bool gone)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(genreModalLinksProvider(session.genre));
    return builder(context, links.asData?.value, GenreModalData.goneOf(links));
  }
}

/// Page of a genre saved in several [folders] (most songs first, as read);
/// [name] is the genre's display name.
ContextModalPage genreModalFoldersPage(
  GenreModalSession session,
  List<AlbumFolder> folders,
  String name,
) {
  final handlers = session.handlers();
  return folderLinksPage(
    key: 'genre-folders',
    title: (l10n) => l10n.genreModalFoldersTitle(name),
    intro: (l10n) => l10n.genreModalFoldersIntro(folders.length),
    folders: folders,
    goToFolder: handlers.goToFolder,
    showInFileManager: handlers.showInFileManager,
    keepAlive: (bar) =>
        GenreLinksKeepAlive(session, builder: (context, links, _) => bar),
  );
}

/// Page of a genre with four or more albums: one row each with the cover, the
/// year and the song count. Row ids are `album-<i>`.
ContextModalPage genreModalAlbumsPage(
  GenreModalSession session,
  List<AlbumSummary> albums,
) {
  final handlers = session.handlers();
  return ContextModalPage(
    key: 'genre-albums',
    headerBuilder: (context, nav) => GenreLinksKeepAlive(
      session,
      builder: (context, links, _) => ContextModalTopBar(
        title: context.l10n.genreModalAlbumsTitle(
          genreDisplayName(context.l10n, session.genre.key, session.genre.name),
        ),
        onBack: nav.pop,
      ),
    ),
    bodyBuilder: (context, nav) {
      final l10n = context.l10n;
      return contextModalSections(nav, [
        [
          for (final (i, album) in albums.indexed)
            ContextModalAction(
              id: 'album-$i',
              icon: AppIcons.albumOutlined,
              leading: AlbumArtwork(
                albumKey: album.key,
                coverKey: album.coverKey,
                size: 40,
              ),
              label: album.title,
              subtitle: joinRowDetails([
                rowYear(album.year),
                l10n.albumsSongCount(album.trackCount),
              ]),
              onTap: contextModalCloseThen(
                () => handlers.goToAlbum(album.key),
              ),
            ),
        ],
      ]);
    },
  );
}
