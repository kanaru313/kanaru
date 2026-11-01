import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/album_links_provider.dart';

import '../../core/database/library_browse_album_links.dart';
import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/library_row.dart';
import 'album_modal_data.dart';
import 'album_modal_session.dart';

/// Page of an album with [artists] (four or more): one row per artist.
ContextModalPage albumModalArtistsPage(
  AlbumModalSession session,
  List<({String key, String name})> artists,
) {
  final handlers = session.handlers();
  return ContextModalPage(
    key: 'album-artists',
    headerBuilder: (context, nav) => ContextModalTopBar(
      title: context.l10n.albumModalArtistsTitle(session.album.title),
      onBack: nav.pop,
    ),
    bodyBuilder: (context, nav) => [
      _KeepLinks(session),
      ...contextModalSections(nav, [
        [
          for (final artist in artists)
            ContextModalAction(
              id: 'artist-${artist.key}',
              icon: AppIcons.artistOutline,
              label: artist.name,
              onTap: albumModalCloseThen(() => handlers.goToArtist(artist.key)),
            ),
        ],
      ], dividers: false),
    ],
  );
}

/// Watches the album's links so they stay alive while a sub page covers the
/// first page; draws nothing.
class _KeepLinks extends ConsumerWidget {
  const _KeepLinks(this.session);

  final AlbumModalSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(albumModalLinksProvider(session.album.key));
    return const SizedBox.shrink();
  }
}

/// Page of an album saved in several [folders] (most songs first, as read):
/// an intro, then a row per folder with its song count and parent path.
ContextModalPage albumModalFoldersPage(
  AlbumModalSession session,
  List<AlbumFolder> folders,
) {
  final handlers = session.handlers();
  return ContextModalPage(
    key: 'album-folders',
    headerBuilder: (context, nav) => ContextModalTopBar(
      title: context.l10n.albumModalFoldersTitle(session.album.title),
      onBack: nav.pop,
    ),
    bodyBuilder: (context, nav) {
      final l10n = context.l10n;
      final theme = Theme.of(context);
      return [
        _KeepLinks(session),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            l10n.albumModalFoldersIntro(folders.length),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...contextModalSections(nav, [
          [
            for (final folder in folders)
              ContextModalAction(
                id: 'folder-${folder.path}',
                icon: AppIcons.folderOutlined,
                label: folderName(folder.path),
                subtitle: joinRowDetails([
                  l10n.albumsSongCount(folder.songCount),
                  parentPath(folder.path),
                ]),
                onTap: albumModalCloseThen(
                  () => handlers.goToFolder(folder.path),
                ),
                trailing: [
                  ContextModalTrailing(
                    icon: AppIcons.openExternal,
                    tooltip: l10n.libraryShowInFileManager,
                    onTap: albumModalCloseThen(
                      () => handlers.showInFileManager(folder.samplePath),
                    ),
                  ),
                ],
              ),
          ],
        ], dividers: false),
      ];
    },
  );
}
