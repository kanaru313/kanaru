import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';
import '../../../../shared/icons/app_icons.dart';
import '../../../../shared/widgets/context_modal/context_modal_route.dart';
import 'folder_modal_links.dart';
import 'folder_modal_session.dart';

/// The Advanced page of the folder context modal: copy path,
/// library exclusion, and delete files.
ContextModalPage folderModalAdvancedPage(FolderModalSession session) =>
    ContextModalPage(
      key: 'folder-advanced',
      headerBuilder: (context, nav) => Consumer(
        builder: (context, ref, _) {
          ref.watch(
            folderModalStatsProvider((
              path: session.folder.path,
              direct: session.direct,
            )),
          );
          return ContextModalTopBar(
            title: context.l10n.songModalAdvanced,
            onBack: nav.pop,
          );
        },
      ),
      bodyBuilder: (context, nav) {
        final l10n = context.l10n;
        final h = session.handlers();
        return [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(nav, [
              [
                ContextModalAction(
                  id: 'copy-path',
                  icon: AppIcons.copy,
                  label: l10n.folderModalCopyPath,
                  subtitle: session.folder.path,
                  onTap: contextModalCloseThen(h.copyPath),
                ),
              ],
              [
                if (!session.folder.isRoot)
                  ContextModalAction(
                    id: 'exclude-from-library',
                    icon: AppIcons.folderOff,
                    label: l10n.folderModalExcludeFromLibrary,
                    subtitle: l10n.albumModalKeepsFiles,
                    onTap: contextModalCloseThen(h.excludeFromLibrary),
                  ),
                ContextModalAction(
                  id: 'delete-files',
                  icon: AppIcons.deleteOutline,
                  label: l10n.albumModalDeleteFiles,
                  destructive: true,
                  comingSoon: true,
                ),
              ],
            ]),
          ),
        ];
      },
    );
