import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/album_links_provider.dart';

import '../../core/database/library_browse_album_links.dart';
import '../../l10n/l10n.dart';
import '../folder_links/folder_links_page.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_route.dart';
import 'album_modal_session.dart';

/// Page of an album with [artists] (four or more): one row per artist.
ContextModalPage albumModalArtistsPage(
  AlbumModalSession session,
  List<({String key, String name})> artists,
) {
  final handlers = session.handlers();
  return ContextModalPage(
    key: 'album-artists',
    headerBuilder: (context, nav) => _KeepLinks(
      session,
      child: ContextModalTopBar(
        title: context.l10n.albumModalArtistsTitle(session.album.title),
        onBack: nav.pop,
      ),
    ),
    bodyBuilder: (context, nav) => [
      ...contextModalSections(nav, [
        [
          for (final artist in artists)
            ContextModalAction(
              id: 'artist-${artist.key}',
              icon: AppIcons.artistOutline,
              label: artist.name,
              onTap: contextModalCloseThen(
                () => handlers.goToArtist(artist.key),
              ),
            ),
        ],
      ]),
    ],
  );
}

/// Watches the album's links so they stay alive while a sub page covers the
/// first page; draws [child]. Sits in the page header, which (unlike a body
/// child) is not disposed when the body scrolls.
class _KeepLinks extends ConsumerWidget {
  const _KeepLinks(this.session, {required this.child});

  final AlbumModalSession session;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(albumModalLinksProvider(session.album.key));
    return child;
  }
}

/// Page of an album saved in several [folders] (most songs first, as read):
/// an intro, then a row per folder with its song count and parent path.
ContextModalPage albumModalFoldersPage(
  AlbumModalSession session,
  List<AlbumFolder> folders,
) {
  final handlers = session.handlers();
  return folderLinksPage(
    key: 'album-folders',
    title: (l10n) => l10n.albumModalFoldersTitle(session.album.title),
    intro: (l10n) => l10n.albumModalFoldersIntro(folders.length),
    folders: folders,
    goToFolder: handlers.goToFolder,
    showInFileManager: handlers.showInFileManager,
    keepAlive: (bar) => _KeepLinks(session, child: bar),
  );
}
