import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/album_links_provider.dart';
import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_route.dart';
import 'album_modal_data.dart';
import 'album_modal_session.dart';

/// The Advanced page: Show in file manager, and the actions not available
/// yet. It watches the album's links itself, which keeps them alive while this
/// page covers the first one.
ContextModalPage albumModalAdvancedPage(AlbumModalSession session) =>
    ContextModalPage(
      key: 'album-advanced',
      headerBuilder: (context, nav) => ContextModalTopBar(
        title: context.l10n.songModalAdvanced,
        onBack: nav.pop,
      ),
      bodyBuilder: (context, nav) => [
        Consumer(
          builder: (context, ref, _) {
            final l10n = context.l10n;
            final links = ref
                .watch(albumModalLinksProvider(session.album.key))
                .asData
                ?.value;
            final main = links?.folders.firstOrNull;
            final handlers = session.handlers();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: contextModalSections(nav, [
                [
                  // Folders are empty for an album with no local file.
                  if (links == null || main != null)
                    ContextModalAction(
                      id: 'show-in-file-manager',
                      icon: AppIcons.folderOpen,
                      label: l10n.libraryShowInFileManager,
                      enabled: main != null,
                      onTap: main == null
                          ? null
                          : albumModalCloseThen(
                              () => handlers.showInFileManager(main.samplePath),
                            ),
                    ),
                ],
                [
                  ContextModalAction(
                    id: 'remove-from-library',
                    icon: AppIcons.removeFromLibrary,
                    label: l10n.songModalRemoveFromLibrary,
                    subtitle: l10n.albumModalKeepsFiles,
                    comingSoon: true,
                  ),
                  ContextModalAction(
                    id: 'delete-files',
                    icon: AppIcons.deleteOutline,
                    label: l10n.albumModalDeleteFiles,
                    subtitle: links == null
                        ? null
                        : l10n.albumModalFilesCount(links.summary.trackCount),
                    destructive: true,
                    comingSoon: true,
                  ),
                ],
              ], dividers: false),
            );
          },
        ),
      ],
    );
