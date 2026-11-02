import '../../l10n/app_localizations.dart';
import '../album_artist_label.dart';
import '../folder_links/folder_link_row.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_spec.dart';
import 'album_modal_data.dart';

/// The Go to artist row for the loaded artists (greyed out while loading).
ContextModalAction _artistRow(
  AppLocalizations l10n,
  AlbumModalData data,
  AlbumModalHandlers h,
) {
  final artists = data.linkedArtists;
  if (artists == null || artists.isEmpty) {
    final album = data.album;
    return ContextModalAction(
      id: 'artist',
      icon: AppIcons.artistOutline,
      label: l10n.songModalGoToArtist,
      subtitle: artists == null
          ? albumArtistLabel(
              l10n,
              artist: album.artist,
              variousArtists: album.variousArtists,
            )
          : l10n.songModalNoArtist,
      enabled: false,
    );
  }
  if (artists.length == 1) {
    final artist = artists.single;
    return ContextModalAction(
      id: 'artist',
      icon: AppIcons.artistOutline,
      label: l10n.songModalGoToArtist,
      subtitle: artist.name,
      onTap: contextModalCloseThen(() => h.goToArtist(artist.key)),
    );
  }
  if (artists.length >= contextModalLinksPageFrom) {
    return ContextModalAction(
      id: 'artists',
      icon: AppIcons.artists,
      label: l10n.songModalGoToArtist,
      subtitle: l10n.songModalArtistsCount(artists.length),
      opensPage: true,
      onTap: h.openArtists,
    );
  }
  return ContextModalAction(
    id: 'artists',
    icon: AppIcons.artists,
    label: l10n.songModalGoToArtist,
    subtitle: l10n.songModalArtistsCount(artists.length),
    chips: ContextModalChips(
      wrap: true,
      initiallyExpanded: true,
      items: [
        for (final artist in artists)
          ContextModalChip(
            label: artist.name,
            onTap: contextModalCloseThen(() => h.goToArtist(artist.key)),
          ),
      ],
    ),
  );
}

/// The rows of the actions page in two groups (links, then album actions);
/// the footer's queue buttons are not here.
List<List<ContextModalAction>> albumModalSections(
  AppLocalizations l10n,
  AlbumModalData data,
  AlbumModalHandlers h,
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
      if (data.showAlbum)
        ContextModalAction(
          id: 'album',
          icon: AppIcons.albumOutlined,
          label: l10n.songModalGoToAlbum,
          subtitle: data.album.title,
          onTap: contextModalCloseThen(h.goToAlbum),
        ),
      _artistRow(l10n, data, h),
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
