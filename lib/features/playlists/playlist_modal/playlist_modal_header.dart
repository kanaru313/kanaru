import 'package:material_ui/material_ui.dart';

import '../../../core/database/playlist_rows.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/context_modal/context_modal_coming_soon_button.dart';
import '../../../shared/widgets/context_modal/context_modal_header.dart';
import '../../../shared/widgets/library_row.dart';
import '../../../shared/widgets/playlist_cover.dart';
import '../playlist_display_name.dart';
import 'playlist_description_box.dart';

const double _coverSize = 64;

/// Top of the playlist modal: the cover, the name, "N songs • Created date"
/// ("Created" is left out for Favorites), the description when there is one,
/// and the Change playlist cover button (not available yet; see
/// [showCoverButton]).
///
/// With [onTap] (Go to playlist, which closes the modal first) the whole
/// header, description included, is one button that does not take keyboard
/// focus: the first row does. It is null on the page of the playlist itself.
class PlaylistModalHeader extends StatelessWidget {
  const PlaylistModalHeader({
    super.key,
    required this.playlist,
    required this.coverKeys,
    this.onTap,
    this.showCoverButton = false,
  });

  final PlaylistSummary playlist;
  final List<String> coverKeys;
  final VoidCallback? onTap;

  /// Shows the Change playlist cover button (not available yet). The caller
  /// leaves it out for Favorites and a playlist that is gone.
  final bool showCoverButton;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final meta = joinRowDetails([
      l10n.albumsSongCount(playlist.entryCount),
      if (!playlist.isFavorites)
        l10n.playlistCreatedOn(
          DateTime.fromMillisecondsSinceEpoch(playlist.createdAt),
        ),
    ]);
    final description = playlist.description;
    return ContextModalHeader(
      leading: PlaylistCover(
        coverKeys: coverKeys,
        size: _coverSize,
        seed: 'playlist:${playlist.id}',
      ),
      lines: [
        contextModalHeaderLine(
          playlistDisplayName(playlist, l10n),
          theme.textTheme.titleMedium,
        ),
        contextModalHeaderLine(meta, quiet),
      ],
      trailing: showCoverButton
          ? ContextModalComingSoonIconButton(
              icon: AppIcons.editAlbumArt,
              tooltip: l10n.playlistModalChangeCover,
            )
          : null,
      below: description.isEmpty
          ? null
          : PlaylistDescriptionBox(text: description, style: quiet),
      onTap: onTap,
      tapHint: l10n.playlistGoTo,
    );
  }
}
