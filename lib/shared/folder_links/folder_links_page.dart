import 'package:material_ui/material_ui.dart';

import '../../core/database/library_browse_album_links.dart';
import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/library_row.dart';
import 'folder_paths.dart';

/// Page of an item saved in several [folders] (most songs first, as read):
/// an intro, then a row per folder with its song count and parent path.
///
/// [title] and [intro] are made from the page's localizations. [keepAlive]
/// wraps the top bar so the caller can watch the provider that feeds
/// [folders] from the header: a body child is disposed once scrolled off, a
/// header is not. [goToFolder] and [showInFileManager] run after the modal
/// has closed.
ContextModalPage folderLinksPage({
  required Object key,
  required String Function(AppLocalizations l10n) title,
  required String Function(AppLocalizations l10n) intro,
  required List<AlbumFolder> folders,
  required ValueChanged<String> goToFolder,
  required ValueChanged<String> showInFileManager,
  required Widget Function(Widget topBar) keepAlive,
}) => ContextModalPage(
  key: key,
  headerBuilder: (context, nav) => keepAlive(
    ContextModalTopBar(title: title(context.l10n), onBack: nav.pop),
  ),
  bodyBuilder: (context, nav) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text(
          intro(l10n),
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
            ),
        ],
      ]),
    ];
  },
);
