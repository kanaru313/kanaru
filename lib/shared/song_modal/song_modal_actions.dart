import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter/widgets.dart' show IconData;

import '../../l10n/app_localizations.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_spec.dart';
import 'song_modal_data.dart';

/// The mockup's ARTISTS_OPEN_BELOW: a song with fewer artists than this
/// shows the artist chips open; with this many or more they start folded.
const artistsOpenBelow = 4;

/// Whether the Song info page exists. Off until the page is built: the row
/// and the header chevron stay hidden.
const songInfoAvailable = false;

/// The folder name shown under Go to folder: the last part of the song's
/// directory.
String songFolderName(String path) {
  final slash = path.lastIndexOf('/');
  if (slash <= 0) return '';
  final dir = path.substring(0, slash);
  return dir.substring(dir.lastIndexOf('/') + 1);
}

/// Go to artist (or album artist) for [artists]: one name is a plain row;
/// several fold their names as chips under a row that says how many.
ContextModalAction _artistsAction(
  AppLocalizations l10n, {
  required String id,
  required String manyId,
  required String label,
  required IconData single,
  required IconData many,
  required List<({String key, String name})> artists,
  required ValueChanged<String> open,
}) {
  if (artists.length == 1) {
    final artist = artists.single;
    return ContextModalAction(
      id: id,
      icon: single,
      label: label,
      subtitle: artist.name,
      onTap: songModalCloseThen(() => open(artist.key)),
    );
  }
  return ContextModalAction(
    id: manyId,
    icon: many,
    label: label,
    subtitle: l10n.songModalArtistsCount(artists.length),
    chips: ContextModalChips(
      initiallyExpanded: artists.length < artistsOpenBelow,
      items: [
        for (final artist in artists)
          ContextModalChip(
            label: artist.name,
            onTap: songModalCloseThen(() => open(artist.key)),
          ),
      ],
    ),
  );
}

/// The rows of the actions page in groups (links, then song actions); the
/// footer's queue buttons are not here. [extra] is the group a screen adds
/// before the links.
List<List<ContextModalAction>> songModalSections(
  AppLocalizations l10n,
  SongModalData data,
  SongModalHandlers h, {
  List<ContextModalAction> extra = const [],
}) {
  final song = data.song;
  final links = data.links;
  final artists = links?.artists ?? const [];
  final albumArtists = links?.albumArtists ?? const [];
  final artistKeys = {for (final a in artists) a.key};
  final albumTitle = song.album?.isNotEmpty ?? false ? song.album : null;
  final isFavorite = data.isFavorite;

  return [
    extra,
    [
      if (data.showAlbum)
        ContextModalAction(
          id: 'album',
          icon: AppIcons.albumOutlined,
          label: l10n.songModalGoToAlbum,
          subtitle: albumTitle ?? l10n.songModalNoAlbum,
          enabled: links?.album != null,
          onTap: songModalCloseThen(h.goToAlbum),
        ),
      if (artists.isEmpty)
        ContextModalAction(
          id: 'artist',
          icon: AppIcons.artistOutline,
          label: l10n.songModalGoToArtist,
          subtitle: links == null && (song.artist?.isNotEmpty ?? false)
              ? song.artist
              : l10n.songModalNoArtist,
          enabled: false,
        )
      else
        _artistsAction(
          l10n,
          id: 'artist',
          manyId: 'artists',
          label: l10n.songModalGoToArtist,
          single: AppIcons.artistOutline,
          many: AppIcons.artists,
          artists: artists,
          open: h.goToArtist,
        ),
      // Only when the album's artist is somebody else than the song's.
      if (albumArtists.isNotEmpty &&
          !albumArtists.every((a) => artistKeys.contains(a.key)))
        _artistsAction(
          l10n,
          id: 'album-artist',
          manyId: 'album-artists',
          label: l10n.songModalGoToAlbumArtist,
          single: AppIcons.albumArtist,
          many: AppIcons.artists,
          artists: albumArtists,
          open: h.goToArtist,
        ),
      if (data.hasLocalPath && data.showFolder)
        ContextModalAction(
          id: 'folder',
          icon: AppIcons.folderOutlined,
          label: l10n.songModalGoToFolder,
          subtitle: songFolderName(song.path),
          onTap: songModalCloseThen(h.goToFolder),
          trailing: [
            ContextModalTrailing(
              icon: AppIcons.openExternal,
              tooltip: l10n.libraryShowInFileManager,
              onTap: songModalCloseThen(h.showInFileManager),
            ),
          ],
        ),
    ],
    [
      ContextModalAction(
        id: 'add-to-playlist',
        icon: AppIcons.addToPlaylist,
        label: l10n.playlistAddTo,
        onTap: songModalCloseThen(h.addToPlaylist),
      ),
      if (data.hasLibrary)
        ContextModalAction(
          id: 'favorite',
          icon: isFavorite ?? false
              ? AppIcons.favorite
              : AppIcons.favoriteOutline,
          label: isFavorite ?? false
              ? l10n.favoritesRemove
              : l10n.nowPlayingFavorite,
          enabled: isFavorite != null,
          onTap: isFavorite == null
              ? null
              : songModalCloseThen(() => h.setFavorite(!isFavorite)),
        ),
      ContextModalAction(
        id: 'edit-tags',
        icon: AppIcons.editTags,
        label: l10n.songModalEditTags,
        comingSoon: true,
      ),
      if (songInfoAvailable)
        ContextModalAction(
          id: 'song-info',
          icon: AppIcons.infoOutline,
          label: l10n.songModalSongInfo,
          opensPage: true,
          onTap: h.openInfo,
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
