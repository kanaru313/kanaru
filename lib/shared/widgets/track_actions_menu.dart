import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/playlist_favorites.dart';
import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../track_menu_actions.dart';
import '../track_menu_choice.dart';
import 'queue_actions_menu.dart';

final _log = Logger('track_menu');

/// Opens the song menu with its corner at [position] (global): the queue
/// rows, the Favorites row, then the links. [hasArtist] and [hasAlbum] grey
/// out Show artist and Show album for a song without one; [showAlbum] false
/// leaves Show album out. [isFavorite] picks "Add to" or "Remove from
/// favorites"; null leaves that row out (no library). Returns null when the
/// menu was dismissed.
Future<TrackMenuChoice?> showTrackActionsMenu(
  BuildContext context,
  Offset position, {
  bool showAlbum = true,
  bool hasArtist = true,
  bool hasAlbum = true,
  bool? isFavorite,
}) {
  final l10n = context.l10n;
  return showMenu<TrackMenuChoice>(
    context: context,
    position: menuPositionAt(context, position),
    items: [
      ...queueActionItems<TrackMenuChoice>(context, QueueChoice.new),
      if (isFavorite != null)
        menuRow(
          FavoriteChoice(favorite: !isFavorite),
          isFavorite ? AppIcons.favorite : AppIcons.favoriteOutline,
          isFavorite ? l10n.favoritesRemove : l10n.nowPlayingFavorite,
        ),
      const PopupMenuDivider(),
      menuRow(
        const ShowArtistChoice(),
        AppIcons.artistOutline,
        l10n.libraryShowArtist,
        enabled: hasArtist,
      ),
      if (showAlbum)
        menuRow(
          const ShowAlbumChoice(),
          AppIcons.albumOutlined,
          l10n.libraryShowAlbum,
          enabled: hasAlbum,
        ),
      menuRow(
        const ShowInFileManagerChoice(),
        AppIcons.folderOpen,
        l10n.libraryShowInFileManager,
      ),
    ],
  );
}

/// Opens the song menu at the pointer on a right click or a long press of
/// [child]. Queue rows go to [onQueueAction]; the links are followed here by
/// the song's [trackId] and [path]. Without [onQueueAction], [child] is
/// returned as is.
class TrackActionsRegion extends ConsumerWidget {
  const TrackActionsRegion({
    super.key,
    required this.trackId,
    required this.path,
    required this.onQueueAction,
    required this.child,
    this.showAlbum = true,
    this.hasArtist = true,
    this.hasAlbum = true,
  });

  final int trackId;
  final String path;
  final ValueChanged<QueueAction>? onQueueAction;
  final Widget child;

  /// False on a page of the song's own album.
  final bool showAlbum;
  final bool hasArtist;
  final bool hasAlbum;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final runner = TrackMenuRunner(ref, context);
    // Read when the menu opens, not from the favorites stream: with no heart
    // on screen that stream is paused and its last value may be stale.
    final isFavorite = await _isFavorite(ref);
    if (!context.mounted) return;
    final choice = await showTrackActionsMenu(
      context,
      position,
      showAlbum: showAlbum,
      hasArtist: hasArtist,
      hasAlbum: hasAlbum,
      isFavorite: isFavorite,
    );
    switch (choice) {
      case null:
        return;
      case QueueChoice(:final action):
        onQueueAction?.call(action);
      case _:
        unawaited(
          runner.run(choice, trackId: trackId, path: path, position: position),
        );
    }
  }

  /// Whether [path] is in Favorites; null without a library or when the read
  /// fails (the menu then leaves the row out).
  Future<bool?> _isFavorite(WidgetRef ref) async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return null;
    try {
      return await db.isFavorite(path);
    } catch (error, stack) {
      _log.warning('Reading whether a song is a favorite failed', error, stack);
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (onQueueAction == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) =>
          _open(context, ref, details.globalPosition),
      onLongPressStart: (details) =>
          _open(context, ref, details.globalPosition),
      child: child,
    );
  }
}
