import '../../core/database/library_browse_album_links.dart';
import '../../l10n/app_localizations.dart';
import '../album_artist_label.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_spec.dart';
import 'album_modal_data.dart';

/// The Go to artist row for the loaded [artists] (null while loading).
ContextModalAction _artistRow(
  AppLocalizations l10n,
  AlbumModalData data,
  AlbumModalHandlers h,
) {
  final artists = data.links?.artists;
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
      onTap: albumModalCloseThen(() => h.goToArtist(artist.key)),
    );
  }
  if (artists.length >= albumArtistsOpenBelow) {
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
            onTap: albumModalCloseThen(() => h.goToArtist(artist.key)),
          ),
      ],
    ),
  );
}

/// The Go to folder row; null when the album has no local folder.
ContextModalAction? _folderRow(
  AppLocalizations l10n,
  AlbumModalData data,
  AlbumModalHandlers h,
) {
  final folders = data.links?.folders;
  if (folders == null) {
    return ContextModalAction(
      id: 'folder',
      icon: AppIcons.folderOutlined,
      label: l10n.songModalGoToFolder,
      enabled: false,
    );
  }
  if (folders.isEmpty) return null;
  if (folders.length == 1) {
    final AlbumFolder folder = folders.single;
    return ContextModalAction(
      id: 'folder',
      icon: AppIcons.folderOutlined,
      label: l10n.songModalGoToFolder,
      subtitle: folderName(folder.path),
      onTap: albumModalCloseThen(() => h.goToFolder(folder.path)),
      trailing: [
        ContextModalTrailing(
          icon: AppIcons.openExternal,
          tooltip: l10n.libraryShowInFileManager,
          onTap: albumModalCloseThen(
            () => h.showInFileManager(folder.samplePath),
          ),
        ),
      ],
    );
  }
  return ContextModalAction(
    id: 'folders',
    icon: AppIcons.folderOutlined,
    label: l10n.songModalGoToFolder,
    // Counts the songs in local folders; with remote tracks it can be lower
    // than the song count in the header.
    subtitle: l10n.albumModalSongsInFolders(
      folders.fold(0, (sum, f) => sum + f.songCount),
      folders.length,
    ),
    opensPage: true,
    onTap: h.openFolders,
  );
}

/// The rows of the actions page in two groups (links, then album actions);
/// the footer's queue buttons are not here.
List<List<ContextModalAction>> albumModalSections(
  AppLocalizations l10n,
  AlbumModalData data,
  AlbumModalHandlers h,
) {
  final folder = _folderRow(l10n, data, h);
  return [
    [
      if (data.showAlbum)
        ContextModalAction(
          id: 'album',
          icon: AppIcons.albumOutlined,
          label: l10n.songModalGoToAlbum,
          subtitle: data.album.title,
          onTap: albumModalCloseThen(h.goToAlbum),
        ),
      _artistRow(l10n, data, h),
      ?folder,
    ],
    [
      ContextModalAction(
        id: 'play-all',
        icon: AppIcons.play,
        label: l10n.albumModalPlayAll,
        onTap: albumModalCloseThen(h.playAll),
      ),
      ContextModalAction(
        id: 'shuffle',
        icon: AppIcons.shuffle,
        label: l10n.libraryShuffle,
        onTap: albumModalCloseThen(h.shuffle),
      ),
      ContextModalAction(
        id: 'add-to-playlist',
        icon: AppIcons.addToPlaylist,
        label: l10n.playlistAddTo,
        onTap: albumModalCloseThen(h.addToPlaylist),
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
