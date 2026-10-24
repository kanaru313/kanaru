import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart';
import '../../l10n/l10n.dart';
import '../album_artist_label.dart';
import '../enqueue_tracks.dart';
import '../icons/app_icons.dart';
import 'album_artwork.dart';
import 'library_row.dart';
import 'queue_actions_menu.dart';

/// Whole minutes of [durationMs], at least 1 for any length above zero.
int _minutes(int durationMs) =>
    durationMs <= 0 ? 0 : math.max(1, (durationMs / 60000).round());

/// One album row: artwork, then three lines (title, "artist • year",
/// "N songs • M min"), then a play button shown while the row is hovered or
/// focused, which plays the whole album. Every line is always laid out, so
/// all rows have the height of the list's prototype row.
class AlbumListTile extends ConsumerStatefulWidget {
  const AlbumListTile({
    super.key,
    required this.album,
    required this.onTap,
    this.onQueueAction,
  });

  final AlbumSummary album;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  ConsumerState<AlbumListTile> createState() => _AlbumListTileState();
}

class _AlbumListTileState extends ConsumerState<AlbumListTile> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    final l10n = context.l10n;
    final styles = libraryRowStyles(Theme.of(context));
    final artistLine = joinRowDetails([
      albumArtistLabel(
        l10n,
        artist: album.artist,
        variousArtists: album.variousArtists,
      ),
      rowYear(album.year),
    ]);
    final durationMs = album.durationMs;
    final countLine = joinRowDetails([
      l10n.albumsSongCount(album.trackCount),
      if (durationMs != null) l10n.albumsMinutes(_minutes(durationMs)),
    ]);
    final showPlay = _hovered || _focused;

    final tile = InkWell(
      onTap: widget.onTap,
      onHover: (hovered) => setState(() => _hovered = hovered),
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: LibraryRowLayout(
        leading: AlbumArtwork(
          albumKey: album.key,
          coverKey: album.coverKey,
          size: libraryRowCoverSize,
        ),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            libraryRowLine(album.title, styles.title),
            libraryRowLine(artistLine, styles.detail),
            libraryRowLine(countLine, styles.detail),
          ],
        ),
        // Always laid out, so the texts keep their width when it shows. Out
        // of the focus order: Enter on the row opens the album, and the
        // button would hide again as focus left the row for it.
        trailing: ExcludeFocus(
          child: ExcludeSemantics(
            excluding: !showPlay,
            child: IgnorePointer(
              ignoring: !showPlay,
              child: AnimatedOpacity(
                opacity: showPlay ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: IconButton.filledTonal(
                  icon: const Icon(AppIcons.playRounded),
                  tooltip: l10n.albumsPlayAlbum,
                  onPressed: () => unawaited(playAlbum(ref, album.key)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return QueueActionsRegion(onAction: widget.onQueueAction, child: tile);
  }
}
