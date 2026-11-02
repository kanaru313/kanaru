import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_browse_album_links.dart';
import '../../core/database/library_browse_rows.dart' show AlbumSummary;
import '../../l10n/l10n.dart';
import '../folder_links/folder_links_page.dart';
import '../icons/app_icons.dart';
import '../widgets/album_artwork.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/library_row.dart';
import 'artist_modal_data.dart';
import 'artist_modal_links.dart';
import 'artist_modal_session.dart';

/// Watches the artist's links so they stay alive while a sub page covers the
/// first page; draws [child]. Sits in the page header, which (unlike a body
/// child) is not disposed when the body scrolls. Also gives [builder] the
/// loaded links, for the pages that show them, and whether the artist is
/// gone (read and found no song; false while loading).
class ArtistLinksKeepAlive extends ConsumerWidget {
  const ArtistLinksKeepAlive(this.session, {super.key, required this.builder});

  final ArtistModalSession session;
  final Widget Function(BuildContext context, ArtistLinks? links, bool gone)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `asData` is null while the links load; Riverpod keeps the previous
    // value while the keys are rewritten, but the album modal reads links
    // the same way, so both modals grey rows out alike.
    final links = ref.watch(artistModalLinksProvider(session.artist.key));
    return builder(context, links.asData?.value, ArtistModalData.goneOf(links));
  }
}

/// Page of an artist saved in several [folders] (most songs first, as read);
/// [name] is the artist's name once loaded.
ContextModalPage artistModalFoldersPage(
  ArtistModalSession session,
  List<AlbumFolder> folders,
  String name,
) {
  final handlers = session.handlers();
  return folderLinksPage(
    key: 'artist-folders',
    title: (l10n) => l10n.artistModalFoldersTitle(name),
    intro: (l10n) => l10n.artistModalFoldersIntro(folders.length),
    folders: folders,
    goToFolder: handlers.goToFolder,
    showInFileManager: handlers.showInFileManager,
    keepAlive: (bar) =>
        ArtistLinksKeepAlive(session, builder: (context, links, _) => bar),
  );
}

/// Group title on the Albums page: not a row, so it takes no focus.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Page of an artist with four or more albums: the albums the artist owns,
/// then those it appears on, one row each with the cover, the year and the
/// song count. Row ids are `album-<i>`, counting across both groups.
ContextModalPage artistModalAlbumsPage(
  ArtistModalSession session,
  List<AlbumSummary> own,
  List<AlbumSummary> appearsOn,
) {
  final handlers = session.handlers();
  return ContextModalPage(
    key: 'artist-albums',
    headerBuilder: (context, nav) => ArtistLinksKeepAlive(
      session,
      builder: (context, links, _) => ContextModalTopBar(
        title: context.l10n.artistModalAlbumsTitle(
          links?.sections.name ?? session.artist.name,
        ),
        onBack: nav.pop,
      ),
    ),
    bodyBuilder: (context, nav) {
      final l10n = context.l10n;
      List<Widget> group(String title, List<AlbumSummary> albums, int first) =>
          [
            _GroupHeading(title),
            ...contextModalSections(nav, [
              [
                for (final (i, album) in albums.indexed)
                  ContextModalAction(
                    id: 'album-${first + i}',
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
            ], dividers: false),
          ];
      return [
        if (own.isNotEmpty) ...group(l10n.artistsAlbums, own, 0),
        if (appearsOn.isNotEmpty)
          ...group(l10n.artistsAppearsOn, appearsOn, own.length),
      ];
    },
  );
}
