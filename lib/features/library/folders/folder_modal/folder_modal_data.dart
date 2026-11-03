import 'package:flutter_riverpod/flutter_riverpod.dart'
    show AsyncData, AsyncValue;

import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/library_row.dart';
import '../folder_tree.dart';
import 'folder_modal_links.dart';

export 'folder_modal_session.dart' show FolderModalHandlers;

/// What the actions page needs to know about the folder, to decide which rows
/// show and which are greyed out.
class FolderModalData {
  const FolderModalData({
    required this.folder,
    required this.direct,
    this.showFolder = true,
    this.stats,
    this.gone = false,
  });

  /// The folder snapshot the modal was opened from.
  final FolderNode folder;

  /// Whether the modal was opened in direct songs view (flat view)
  /// or recursive tree view.
  final bool direct;

  /// False on the page of the folder itself.
  final bool showFolder;

  /// Resolved counts and duration, or null while loading.
  final FolderStats? stats;

  /// The folder holds no songs or was removed from the library.
  final bool gone;

  /// Whether [stats] resolved to null; loading and errors are not gone.
  static bool goneOf(AsyncValue<FolderStats?> async) =>
      async is AsyncData<FolderStats?> && async.value == null;

  /// Formatted subtitle line: "N songs • M subfolders • length".
  String statsLine(AppLocalizations l10n) {
    final count = direct ? folder.directSongs : folder.songs;
    final songCountStr = l10n.albumsSongCount(count);
    final subfoldersStr = !direct && folder.subfolders > 0
        ? l10n.foldersSubfolderCount(folder.subfolders)
        : null;
    final durationStr = stats?.durationMs != null
        ? rowLength(l10n, stats!.durationMs)
        : null;
    return joinRowDetails([songCountStr, subfoldersStr, durationStr]);
  }
}
