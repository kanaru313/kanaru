import '../../l10n/app_localizations.dart';
import '../folder_links/folder_link_row.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_spec.dart';
import 'genre_modal_data.dart';

/// The album row: Go to album for one album, Go to albums for several (chips
/// up to the point where a page reads better), greyed out while loading.
ContextModalAction _albumRow(
  AppLocalizations l10n,
  GenreModalData data,
  GenreModalHandlers h,
) {
  final links = data.links;
  if (links == null) {
    return ContextModalAction(
      id: 'album',
      icon: AppIcons.albumOutlined,
      label: l10n.songModalGoToAlbum,
      enabled: false,
    );
  }
  final albums = links.albums;
  if (albums.isEmpty) {
    return ContextModalAction(
      id: 'album',
      icon: AppIcons.albumOutlined,
      label: l10n.songModalGoToAlbum,
      subtitle: l10n.songModalNoAlbum,
      enabled: false,
    );
  }
  if (albums.length == 1) {
    final album = albums.single;
    return ContextModalAction(
      id: 'album',
      icon: AppIcons.albumOutlined,
      label: l10n.songModalGoToAlbum,
      subtitle: album.title,
      onTap: contextModalCloseThen(() => h.goToAlbum(album.key)),
    );
  }
  final subtitle = l10n.artistsAlbumCount(albums.length);
  if (albums.length >= contextModalLinksPageFrom) {
    return ContextModalAction(
      id: 'albums',
      icon: AppIcons.albumOutlined,
      label: l10n.songModalGoToAlbum,
      subtitle: subtitle,
      opensPage: true,
      onTap: h.openAlbums,
    );
  }
  return ContextModalAction(
    id: 'albums',
    icon: AppIcons.albumOutlined,
    label: l10n.songModalGoToAlbum,
    subtitle: subtitle,
    chips: ContextModalChips(
      wrap: true,
      initiallyExpanded: true,
      items: [
        for (final album in albums)
          ContextModalChip(
            label: album.title,
            onTap: contextModalCloseThen(() => h.goToAlbum(album.key)),
          ),
      ],
    ),
  );
}

/// The rows of the actions page in two groups (links, then genre actions);
/// the footer's queue buttons are not here.
List<List<ContextModalAction>> genreModalSections(
  AppLocalizations l10n,
  GenreModalData data,
  GenreModalHandlers h,
) {
  final folder = folderLinkRow(
    l10n,
    data.links?.folders,
    goToFolder: h.goToFolder,
    showInFileManager: h.showInFileManager,
    openFolders: h.openFolders,
  );
  return [
    [
      if (data.showGenre)
        ContextModalAction(
          id: 'genre',
          icon: AppIcons.genre,
          label: l10n.songModalGoToGenre,
          subtitle: data.displayName(l10n),
          onTap: contextModalCloseThen(h.goToGenre),
        ),
      _albumRow(l10n, data, h),
      ?folder,
    ],
    [
      ContextModalAction(
        id: 'play-all',
        icon: AppIcons.play,
        label: l10n.albumModalPlayAll,
        enabled: !data.gone,
        onTap: contextModalCloseThen(h.playAll),
      ),
      ContextModalAction(
        id: 'shuffle',
        icon: AppIcons.shuffle,
        label: l10n.libraryShuffle,
        enabled: !data.gone,
        onTap: contextModalCloseThen(h.shuffle),
      ),
      ContextModalAction(
        id: 'add-to-playlist',
        icon: AppIcons.addToPlaylist,
        label: l10n.playlistAddTo,
        enabled: !data.gone,
        onTap: contextModalCloseThen(h.addToPlaylist),
      ),
      ContextModalAction(
        id: 'edit-tags',
        icon: AppIcons.editTags,
        label: l10n.songModalEditTags,
        comingSoon: true,
      ),
      ContextModalAction(
        id: 'advanced',
        icon: AppIcons.advanced,
        label: l10n.songModalAdvanced,
        opensPage: true,
        onTap: h.openAdvanced,
      ),
    ],
  ];
}
