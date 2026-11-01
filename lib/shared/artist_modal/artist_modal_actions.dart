import '../../core/database/library_browse_rows.dart' show AlbumSummary;
import '../../l10n/app_localizations.dart';
import '../folder_links/folder_link_row.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_spec.dart';
import '../widgets/library_row.dart';
import 'artist_modal_data.dart';

/// The albums of the artist, own first and then the ones it appears on: the
/// order of the chips and of the Albums page.
List<AlbumSummary> artistModalAlbums(ArtistModalData data) {
  final sections = data.links?.sections;
  return sections == null
      ? const []
      : [...sections.albums, ...sections.appearsOn];
}

/// The album row: Go to album for one album, Go to albums for several (chips
/// up to the point where a page reads better), greyed out while loading.
ContextModalAction _albumRow(
  AppLocalizations l10n,
  ArtistModalData data,
  ArtistModalHandlers h,
) {
  final sections = data.links?.sections;
  if (sections == null) {
    return ContextModalAction(
      id: 'album',
      icon: AppIcons.albumOutlined,
      label: l10n.songModalGoToAlbum,
      enabled: false,
    );
  }
  final albums = artistModalAlbums(data);
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
  final own = sections.albums.length;
  final other = sections.appearsOn.length;
  final subtitle = joinRowDetails([
    if (own > 0) l10n.artistsAlbumCount(own),
    if (other > 0) l10n.artistModalAppearsOnCount(other),
  ]);
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

/// The rows of the actions page in two groups (links, then artist actions);
/// the footer's queue buttons are not here.
List<List<ContextModalAction>> artistModalSections(
  AppLocalizations l10n,
  ArtistModalData data,
  ArtistModalHandlers h,
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
      if (data.showArtist)
        ContextModalAction(
          id: 'artist',
          icon: AppIcons.artistOutline,
          label: l10n.songModalGoToArtist,
          subtitle: data.displayName,
          onTap: contextModalCloseThen(h.goToArtist),
        ),
      _albumRow(l10n, data, h),
      ?folder,
    ],
    [
      ContextModalAction(
        id: 'play-all',
        icon: AppIcons.play,
        label: l10n.albumModalPlayAll,
        onTap: contextModalCloseThen(h.playAll),
      ),
      ContextModalAction(
        id: 'shuffle',
        icon: AppIcons.shuffle,
        label: l10n.libraryShuffle,
        onTap: contextModalCloseThen(h.shuffle),
      ),
      ContextModalAction(
        id: 'add-to-playlist',
        icon: AppIcons.addToPlaylist,
        label: l10n.playlistAddTo,
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
