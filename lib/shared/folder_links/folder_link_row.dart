import 'package:flutter/widgets.dart' show ValueChanged;

import '../../core/database/library_browse_album_links.dart';
import '../../l10n/app_localizations.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_spec.dart';
import '../widgets/context_modal/context_modal_nav.dart';
import 'folder_paths.dart';

/// The Go to folder row of an item modal for its [folders] (null while they
/// load, which greys the row out); null when there is no local folder.
///
/// One folder shows its name and a show-in-file-manager button; several open
/// a page through [openFolders]. [goToFolder] gets the folder path and
/// [showInFileManager] a sample file inside it; both run after the modal
/// has closed.
ContextModalAction? folderLinkRow(
  AppLocalizations l10n,
  List<AlbumFolder>? folders, {
  required ValueChanged<String> goToFolder,
  required ValueChanged<String> showInFileManager,
  required void Function(ContextModalNav nav)? openFolders,
}) {
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
      onTap: contextModalCloseThen(() => goToFolder(folder.path)),
      trailing: [
        ContextModalTrailing(
          icon: AppIcons.openExternal,
          tooltip: l10n.libraryShowInFileManager,
          onTap: contextModalCloseThen(
            () => showInFileManager(folder.samplePath),
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
    onTap: openFolders,
  );
}
