import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/database/playlist_favorites.dart';
import '../../../core/database/playlist_library_paths.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/playing_track_art.dart' show localPathOf;
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/menu_keyboard_region.dart';
import '../../../shared/widgets/queue_actions_menu.dart';

final _log = Logger('queue');

enum _QueueTileAction { like, unlike, remove }

/// The menu of a queue row, on a right click, a long press or the menu key:
/// add the song to Favorites or take it out (the heart), and remove it from
/// the queue. Only a song of the library can be added, as everywhere else;
/// any song in Favorites can be taken out.
class QueueTileMenuRegion extends ConsumerWidget {
  const QueueTileMenuRegion({
    super.key,
    required this.track,
    required this.position,
    required this.child,
  });

  final Track track;

  /// Play position of the row, for "remove".
  final int position;
  final Widget child;

  /// Whether the song is in Favorites and in the library, read when the menu
  /// opens; null without a library, for a file that is not local or when
  /// the read fails (the menu then has no heart).
  Future<({bool favorite, bool inLibrary})?> _favoriteState(
    WidgetRef ref,
    String? path,
  ) async {
    final db = ref.read(libraryDatabaseProvider);
    if (db == null || path == null) return null;
    try {
      final favorite = await db.isFavorite(path);
      final inLibrary = (await db.libraryPathsAmong([path])).contains(path);
      return (favorite: favorite, inLibrary: inLibrary);
    } catch (error, stack) {
      _log.warning('Reading whether a song is a favorite failed', error, stack);
      return null;
    }
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final player = ref.read(playerServiceProvider.notifier);
    final db = ref.read(libraryDatabaseProvider);
    final path = localPathOf(track.uri);
    // The entry, not the track: the same Track object may be queued twice.
    final container = ProviderScope.containerOf(context, listen: false);
    final queueAtOpen = container.read(playerServiceProvider).queue;
    final entry = this.position < queueAtOpen.order.length
        ? queueAtOpen.order[this.position]
        : null;
    final state = await _favoriteState(ref, path);
    if (!context.mounted) return;
    final action = await showMenu<_QueueTileAction>(
      context: context,
      position: menuPositionAt(context, position),
      items: [
        if (state != null && state.favorite)
          menuRow(
            _QueueTileAction.unlike,
            AppIcons.favorite,
            l10n.favoritesRemove,
          )
        else if (state != null && state.inLibrary)
          menuRow(
            _QueueTileAction.like,
            AppIcons.favoriteOutline,
            l10n.nowPlayingFavorite,
          ),
        menuRow(
          _QueueTileAction.remove,
          AppIcons.deleteRounded,
          l10n.queueRemove,
        ),
      ],
    );
    void say(String text) => messenger
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
    switch (action) {
      case null:
        return;
      case _QueueTileAction.remove:
        // The queue may have changed while the menu was open: remove the
        // entry only if it is still at that position. Read through the
        // container taken before the menu opened, as the row may be gone.
        final queue = container.read(playerServiceProvider).queue;
        if (entry != null &&
            this.position < queue.order.length &&
            queue.order[this.position] == entry) {
          await player.removeTrack(this.position);
        }
      case _QueueTileAction.like || _QueueTileAction.unlike:
        if (db == null || path == null) return;
        final like = action == _QueueTileAction.like;
        try {
          await db.setFavorite(
            path,
            favorite: like,
            now: DateTime.now().millisecondsSinceEpoch,
          );
          say(like ? l10n.favoritesAdded : l10n.favoritesRemoved);
        } catch (error, stack) {
          _log.severe('Changing the favorite of a song failed', error, stack);
          say(l10n.playlistSaveFailed);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => MenuKeyboardRegion(
    onOpen: (position) => _open(context, ref, position),
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) =>
          _open(context, ref, details.globalPosition),
      onLongPressStart: (details) =>
          _open(context, ref, details.globalPosition),
      child: child,
    ),
  );
}
