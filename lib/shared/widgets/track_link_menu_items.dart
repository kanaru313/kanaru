import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../track_menu_choice.dart';
import 'queue_actions_menu.dart';

/// The rows after the queue rows of the song menu: the Favorites row (left
/// out when [isFavorite] is null), a divider, Show artist, Show album, Show in
/// folder and Show in file manager. [showFindLyrics] adds Find lyrics online
/// after the divider. [showLinks] false also leaves out Show
/// artist, Show album and Show in folder, for songs that are not rows of the
/// library; [showFileManager] false leaves out Show in file manager, for songs
/// that are not local files.
List<PopupMenuEntry<TrackMenuChoice>> trackLinkMenuItems(
  BuildContext context, {
  bool? isFavorite,
  bool showFindLyrics = false,
  bool showAlbum = true,
  bool hasArtist = true,
  bool hasAlbum = true,
  bool showLinks = true,
  bool showFileManager = true,
}) {
  final l10n = context.l10n;
  return [
    if (isFavorite != null)
      menuRow(
        FavoriteChoice(favorite: !isFavorite),
        isFavorite ? AppIcons.favorite : AppIcons.favoriteOutline,
        isFavorite ? l10n.favoritesRemove : l10n.nowPlayingFavorite,
      ),
    const PopupMenuDivider(),
    if (showFindLyrics)
      menuRow(const FindLyricsChoice(), AppIcons.lyrics, l10n.lyricsFindOnline),
    if (showLinks) ...[
      menuRow(
        const ShowArtistChoice(),
        AppIcons.artistOutline,
        l10n.libraryShowArtist,
        enabled: hasArtist,
      ),
      if (showAlbum)
        menuRow(
          const ShowAlbumChoice(),
          AppIcons.albumOutlined,
          l10n.libraryShowAlbum,
          enabled: hasAlbum,
        ),
      menuRow(
        const ShowFolderChoice(),
        AppIcons.folderOutlined,
        l10n.libraryShowInFolder,
      ),
    ],
    if (showFileManager)
      menuRow(
        const ShowInFileManagerChoice(),
        AppIcons.folderOpen,
        l10n.libraryShowInFileManager,
      ),
  ];
}
