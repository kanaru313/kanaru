import 'package:material_ui/material_ui.dart';

import '../../../core/database/playlist_rows.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/library_row.dart';
import '../../../shared/widgets/playlist_cover.dart';
import '../playlist_display_name.dart';
import 'playlist_description_box.dart';

const double _coverSize = 64;

/// Top of the playlist modal: the cover, the name, "N songs • Created date"
/// ("Created" is left out for Favorites), the description when there is one,
/// and the Edit button (not for Favorites).
///
/// With [onTap] (Go to playlist, which closes the modal first) the cover and
/// the text are one button that does not take keyboard focus: the first row
/// does. It is null on the page of the playlist itself.
class PlaylistModalHeader extends StatelessWidget {
  const PlaylistModalHeader({
    super.key,
    required this.playlist,
    required this.coverKeys,
    this.onTap,
    this.onEdit,
  });

  final PlaylistSummary playlist;
  final List<String> coverKeys;
  final VoidCallback? onTap;

  /// Null leaves the Edit button out.
  final VoidCallback? onEdit;

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
    Widget line(String text, TextStyle? style) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final identity = Row(
      spacing: 16,
      children: [
        PlaylistCover(
          coverKeys: coverKeys,
          size: _coverSize,
          seed: 'playlist:${playlist.id}',
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              line(
                playlistDisplayName(playlist, l10n),
                theme.textTheme.titleMedium,
              ),
              line(meta, quiet),
            ],
          ),
        ),
      ],
    );
    final tap = onTap;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: tap == null
                    ? identity
                    : Semantics(
                        button: true,
                        hint: l10n.playlistGoTo,
                        child: InkWell(
                          canRequestFocus: false,
                          borderRadius: BorderRadius.circular(12),
                          onTap: tap,
                          child: identity,
                        ),
                      ),
              ),
              if (onEdit != null)
                IconButton(
                  key: const ValueKey('playlist-modal-edit'),
                  tooltip: l10n.playlistEditAction,
                  icon: const Icon(AppIcons.edit),
                  color: colors.onSurfaceVariant,
                  onPressed: onEdit,
                ),
            ],
          ),
          if (playlist.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 10),
              child: PlaylistDescriptionBox(
                text: playlist.description,
                style: quiet,
              ),
            ),
        ],
      ),
    );
  }
}
