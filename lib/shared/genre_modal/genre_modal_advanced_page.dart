import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_route.dart';
import 'genre_modal_session.dart';
import 'genre_modal_sub_pages.dart';

/// The Advanced page: Add all to Favorites, Show in file manager, and the
/// actions not available yet. It watches the genre's links itself, which
/// keeps them alive while this page covers the first one; a gone genre greys
/// out Add all to Favorites.
ContextModalPage genreModalAdvancedPage(GenreModalSession session) =>
    ContextModalPage(
      key: 'genre-advanced',
      headerBuilder: (context, nav) => GenreLinksKeepAlive(
        session,
        builder: (context, links, _) => ContextModalTopBar(
          title: context.l10n.songModalAdvanced,
          onBack: nav.pop,
        ),
      ),
      bodyBuilder: (context, nav) {
        final l10n = context.l10n;
        final genre = session.genre;
        final handlers = session.handlers();
        return [
          GenreLinksKeepAlive(
            session,
            builder: (context, links, gone) {
              final main = links?.folders.firstOrNull;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: contextModalSections(nav, [
                  [
                    ContextModalAction(
                      id: 'add-all-to-favorites',
                      icon: AppIcons.favoriteOutline,
                      label: l10n.albumModalAddAllToFavorites,
                      enabled: !gone,
                      onTap: contextModalCloseThen(handlers.addAllToFavorites),
                    ),
                  ],
                  [
                    // No folder when the genre has no local file.
                    if (links == null || main != null)
                      ContextModalAction(
                        id: 'show-in-file-manager',
                        icon: AppIcons.folderOpen,
                        label: l10n.libraryShowInFileManager,
                        subtitle: main?.path,
                        enabled: main != null,
                        onTap: main == null
                            ? null
                            : contextModalCloseThen(
                                () =>
                                    handlers.showInFileManager(main.samplePath),
                              ),
                      ),
                  ],
                  [
                    ContextModalAction(
                      id: 'split-merge',
                      icon: AppIcons.splitArtist,
                      label: l10n.genreModalSplitMerge,
                      subtitle: l10n.genreModalSplitMergeHint,
                      comingSoon: true,
                    ),
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
                      subtitle: l10n.albumModalFilesCount(genre.songCount),
                      destructive: true,
                      comingSoon: true,
                    ),
                  ],
                ]),
              );
            },
          ),
        ];
      },
    );
