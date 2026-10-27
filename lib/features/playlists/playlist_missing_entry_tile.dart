import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/cover_art.dart';
import '../../shared/widgets/favorite_button.dart';
import '../../shared/widgets/hover_reveal_action.dart';
import '../../shared/widgets/library_row.dart';
import '../../shared/widgets/song_card.dart';
import 'playlist_entry_handle.dart';

/// The row of an entry whose file is not in the library: handle, an empty
/// cover, the file name and "Not in library". Dimmed, not tappable, no menu.
/// The row has the height of a `SongTile`.
///
/// Trailing: a hover-reveal remove button when [onRemove] is set; otherwise a
/// heart when [showFavorite] (Favorites, where a file that left the library
/// can still be unliked); otherwise nothing.
class PlaylistMissingEntryTile extends StatelessWidget {
  const PlaylistMissingEntryTile({
    super.key,
    required this.entry,
    required this.index,
    this.reorderable = true,
    this.onRemove,
    this.showFavorite = false,
  });

  final PlaylistEntryRow entry;

  /// Position in the list as shown, for the drag handle.
  final int index;

  /// Whether the drag handle shows.
  final bool reorderable;

  /// Null leaves the remove button out.
  final VoidCallback? onRemove;

  /// Shows a heart for the entry's path when [onRemove] is null.
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = libraryRowStyles(Theme.of(context));
    final cover = CoverArt(
      path: null,
      size: libraryRowCoverSize,
      placeholder: const Center(child: Icon(AppIcons.musicOff)),
    );

    Widget row(bool revealed) => SongCardFrame(
      child: LibraryRowLayout(
        horizontalPadding: 32 - songCardInset,
        leading: reorderable
            ? Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  PlaylistEntryHandle(index: index),
                  cover,
                ],
              )
            : cover,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            libraryRowLine(entry.path.split('/').last, styles.title),
            libraryRowLine(l10n.playlistNotInLibrary, styles.detail),
            libraryRowLine('', styles.detail),
          ],
        ),
        trailing: onRemove != null
            ? RevealableAction(
                revealed: revealed,
                child: IconButton(
                  icon: const Icon(AppIcons.closeRounded),
                  iconSize: 20,
                  tooltip: l10n.playlistRemoveEntry,
                  onPressed: onRemove,
                ),
              )
            : showFavorite
            ? FavoriteButton(path: entry.path, iconSize: 20, compact: true)
            : null,
      ),
    );

    return Opacity(
      opacity: 0.6,
      child: onRemove == null
          ? row(false)
          : HoverRevealAction(builder: (_, revealed) => row(revealed)),
    );
  }
}
