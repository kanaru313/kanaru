import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_browse_track_links.dart';
import '../../../core/database/library_startup.dart';
import '../../../core/database/playlist_favorites.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/playing_track_art.dart' show localPathOf;
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/menu_keyboard_region.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/track_actions_menu.dart'
    show trackLinkMenuItems;
import 'queue_tile.dart' show isUpNextRow;
import 'queue_tile_menu_actions.dart';

final _log = Logger('queue');

/// The menu of a queue row, on a right click, a long press or the menu key:
/// Play next (a move, never a copy), Add to playlist, the Favorites row, the
/// artist and album links, Show in file manager and Remove from queue. Songs
/// outside the library get no playlist, no Add to favorites and no links;
/// any song in Favorites can be taken out. Every action is checked against
/// the queue when picked, so a queue replaced meanwhile is left alone.
class QueueTileMenuRegion extends ConsumerWidget {
  const QueueTileMenuRegion({
    super.key,
    required this.track,
    required this.position,
    required this.child,
  });

  final Track track;

  /// Play position of the row.
  final int position;
  final Widget child;

  /// What the database says of the song at [path] when the menu opens: whether
  /// it is a favorite and its library row. Both null without a library, for a
  /// file that is not local or when a read fails (the menu is then cut down
  /// to the queue rows and the file manager).
  Future<({bool? favorite, ({int id, bool hasArtist, bool hasAlbum})? state})>
  _read(ProviderContainer container, String? path) async {
    final db = container.read(libraryDatabaseProvider);
    if (db == null || path == null) return (favorite: null, state: null);
    try {
      final (favorite, state) = await (
        db.isFavorite(path),
        db.trackMenuStateOfPath(path),
      ).wait;
      return (favorite: favorite, state: state);
    } catch (error, stack) {
      _log.warning('Reading a queue row for its menu failed', error, stack);
      return (favorite: null, state: null);
    }
  }

  /// Find lyrics online is offered for a local file, tagged or not, when the
  /// library is open (a pick is stored there).
  bool _canFindLyrics(ProviderContainer container, String? path) =>
      path != null && container.read(libraryDatabaseProvider) != null;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    // Everything the actions need is captured here: after the menu or the
    // reads the row may be gone (the sheet closes when the queue empties).
    final container = ProviderScope.containerOf(context, listen: false);
    final queue = container.read(playerServiceProvider).queue;
    if (this.position >= queue.order.length) return;
    final entry = queue.order[this.position];
    final trackAtOpen = queue.original[entry];
    final current = this.position == queue.index;
    final inRun = isUpNextRow(
      queue,
      this.position,
      container.read(playerServiceProvider.notifier).upNextRun,
    );
    final l10n = context.l10n;
    final path = localPathOf(trackAtOpen.uri);
    final runner = TrackMenuRunner(ref, context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    final (:favorite, :state) = await _read(container, path);
    if (!context.mounted) return;
    final links = trackLinkMenuItems(
      context,
      hasArtist: state?.hasArtist ?? false,
      hasAlbum: state?.hasAlbum ?? false,
      showLinks: state != null,
      showFileManager: path != null,
      showFindLyrics: _canFindLyrics(container, path),
    );
    final choice = await showMenu<Object>(
      context: context,
      position: menuPositionAt(context, position),
      items: tidyDividers<Object>([
        ...queueRowLeadingItems(
          l10n,
          playNext: !current && !inRun,
          addToPlaylist: state != null,
          favorite: favorite,
          inLibrary: state != null,
        ),
        const PopupMenuDivider(),
        ...links,
        const PopupMenuDivider(),
        menuRow<Object>(
          QueueRowChoice.remove,
          AppIcons.deleteRounded,
          l10n.queueRemove,
        ),
      ]),
    );
    if (choice == null) return;
    await QueueRowMenuTarget(
      container: container,
      entry: entry,
      track: trackAtOpen,
      path: path,
      trackId: state?.id,
      runner: runner,
      messenger: messenger,
      l10n: l10n,
      navigator: navigator,
      position: position,
    ).run(choice);
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
