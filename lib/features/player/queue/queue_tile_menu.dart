import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_track_of_path.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/playing_track_art.dart' show localPathOf;
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/menu_keyboard_region.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/track_link_menu_items.dart'
    show trackLinkMenuItems;
import 'queue_song_modal.dart';
import 'queue_tile.dart' show isUpNextRow;
import 'queue_tile_menu_actions.dart';
import 'queue_tile_menu_state.dart';

/// The menu of a queue row, on a right click, a long press or the menu key.
/// A song of the library opens the song modal (see [openQueueSongModal]).
/// The row's ⋮ button reaches the same menu through [openQueueRowMenu].
/// Any other song (a stream, a file outside the library, no library open)
/// gets a cut-down popup: Play next (a move, never a copy), the Favorites
/// row (any song in Favorites can be taken out), Find lyrics online, Show in
/// file manager and Remove from queue. Every action is checked against the
/// queue when picked, so a queue replaced meanwhile is left alone.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) => MenuKeyboardRegion(
    onOpen: (position) => openQueueRowMenu(
      context,
      ref,
      position: this.position,
      at: position,
      viaKeyboard: true,
    ),
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) => openQueueRowMenu(
        context,
        ref,
        position: position,
        at: details.globalPosition,
      ),
      onLongPressStart: (details) => openQueueRowMenu(
        context,
        ref,
        position: position,
        at: details.globalPosition,
      ),
      child: child,
    ),
  );
}

/// Opens the menu of the queue row at [position] (the song modal for a
/// library song, a popup otherwise) at [at]. Shared by the gestures and the
/// row's ⋮ button.
Future<void> openQueueRowMenu(
  BuildContext context,
  WidgetRef ref, {
  required int position,
  required Offset at,
  bool viaKeyboard = false,
}) async {
  // Everything the actions need is captured here: after the menu or the
  // reads the row may be gone (the sheet closes when the queue empties).
  final container = ProviderScope.containerOf(context, listen: false);
  final queue = container.read(playerServiceProvider).queue;
  if (position >= queue.order.length) return;
  final entry = queue.order[position];
  final trackAtOpen = queue.original[entry];
  final current = position == queue.index;
  final inRun = isUpNextRow(
    queue,
    position,
    container.read(playerServiceProvider.notifier).upNextRun,
  );
  final l10n = context.l10n;
  final path = localPathOf(trackAtOpen.uri);
  final runner = TrackMenuRunner(ref, context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  // The library row of the song is watched by the row, so it is there
  // already and the modal opens in this very frame; only a row opened
  // before that read ended waits for it.
  final provider = path == null ? null : libraryTrackOfPathProvider(path);
  var item = provider == null ? null : ref.read(provider).value;
  if (item == null && provider != null && ref.read(provider).isLoading) {
    item = await ref.read(provider.future);
    if (!context.mounted) return;
  }
  if (item != null) {
    openQueueSongModal(
      context,
      ref,
      item: item,
      viaKeyboard: viaKeyboard,
      target: QueueRowMenuTarget(
        container: container,
        entry: entry,
        track: trackAtOpen,
        path: path,
        trackId: item.id,
        runner: runner,
        messenger: messenger,
        l10n: l10n,
        navigator: navigator,
        position: at,
      ),
    );
    return;
  }

  final (:favorite, :state) = await readQueueRowState(container, path);
  if (!context.mounted) return;
  final links = trackLinkMenuItems(
    context,
    hasArtist: state?.hasArtist ?? false,
    hasAlbum: state?.hasAlbum ?? false,
    showLinks: state != null,
    showFileManager: path != null,
    showFindLyrics: canFindLyricsForRow(container, path),
  );
  final choice = await showMenu<Object>(
    context: context,
    position: menuPositionAt(context, at),
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
    position: at,
  ).run(choice);
}
