import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_route.dart';
import 'artist_modal_session.dart';
import 'artist_modal_sub_pages.dart';

/// The Advanced page: Add all to Favorites, Show in file manager, and the
/// actions not available yet. It watches the artist's links itself, which
/// keeps them alive while this page covers the first one.
ContextModalPage artistModalAdvancedPage(ArtistModalSession session) =>
    ContextModalPage(
      key: 'artist-advanced',
      headerBuilder: (context, nav) => ArtistLinksKeepAlive(
        session,
        builder: (context, links) => ContextModalTopBar(
          title: context.l10n.songModalAdvanced,
          onBack: nav.pop,
        ),
      ),
      bodyBuilder: (context, nav) {
        final l10n = context.l10n;
        final artist = session.artist;
        final handlers = session.handlers();
        return [
          ArtistLinksKeepAlive(
            session,
            builder: (context, links) {
              final main = links?.folders.firstOrNull;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: contextModalSections(nav, [
                  [
                    ContextModalAction(
                      id: 'add-all-to-favorites',
                      icon: AppIcons.favoriteOutline,
                      label: l10n.albumModalAddAllToFavorites,
                      onTap: contextModalCloseThen(handlers.addAllToFavorites),
                    ),
                  ],
                  [
                    // No folder when the artist has no local file.
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
                      label: l10n.artistModalSplitMerge,
                      subtitle: l10n.artistModalSplitMergeHint,
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
                      subtitle: l10n.albumModalFilesCount(artist.songCount),
                      destructive: true,
                      comingSoon: true,
                    ),
                  ],
                ], dividers: false),
              );
            },
          ),
        ];
      },
    );
