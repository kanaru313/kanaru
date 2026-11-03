import '../../../../l10n/l10n.dart';
import '../../../../shared/icons/app_icons.dart';
import '../../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../../../../shared/widgets/context_modal/context_modal_spec.dart';
import 'folder_modal_data.dart';

/// Pure row builder for the folder context modal: navigation group,
/// then playback, playlist and advanced actions.
List<List<ContextModalAction>> folderModalSections(
  AppLocalizations l10n,
  FolderModalData data,
  FolderModalHandlers h, {
  required void Function(ContextModalNav) openAdvanced,
}) {
  final playAllBelow = h.playAllBelow;
  return [
    [
      if (data.showFolder)
        ContextModalAction(
          id: 'folder',
          icon: AppIcons.folderOutlined,
          label: l10n.songModalGoToFolder,
          subtitle: data.folder.label,
          onTap: contextModalCloseThen(h.goToFolder),
          trailing: [
            ContextModalTrailing(
              icon: AppIcons.openExternal,
              tooltip: l10n.libraryShowInFileManager,
              onTap: contextModalCloseThen(
                () => h.showInFileManager(data.stats?.samplePath),
              ),
            ),
          ],
        ),
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
      if (data.direct && data.folder.children.isNotEmpty)
        ContextModalAction(
          id: 'play-all-below',
          icon: AppIcons.playlistPlay,
          label: l10n.foldersPlayAllBelow,
          enabled: !data.gone && playAllBelow != null,
          onTap: playAllBelow == null
              ? null
              : contextModalCloseThen(playAllBelow),
        ),
      ContextModalAction(
        id: 'add-to-playlist',
        icon: AppIcons.addToPlaylist,
        label: l10n.playlistAddTo,
        enabled: !data.gone,
        onTap: contextModalCloseThen(h.addToPlaylist),
      ),
      ContextModalAction(
        id: 'create-playlist',
        icon: AppIcons.newPlaylist,
        label: l10n.foldersCreatePlaylist,
        enabled: !data.gone,
        onTap: contextModalCloseThen(h.createPlaylist),
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
        onTap: openAdvanced,
      ),
    ],
  ];
}
