import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_track_of_path.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/playing_track_art.dart' show localPathOf;
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/track_menu_actions.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../../../shared/widgets/track_link_menu_items.dart'
    show trackLinkMenuItems;
import 'queue_song_modal.dart';
import 'queue_tile.dart' show isUpNextRow;
import 'queue_tile_menu_actions.dart';
import 'queue_tile_menu_state.dart';

/// Opens the menu of the queue row at [position], from a right click, a
/// long press, the menu key or the row's ⋮ button, anchored at [at] (global).
/// A song of the library opens the song modal (see [openQueueSongModal]).
/// Any other song (a stream, a file outside the library, no library open)
/// gets a cut-down popup: Play next (a move, never a copy), the Favorites
/// row (any song in Favorites can be taken out), Find lyrics online, Show in
/// file manager and Remove from queue. Every action is checked against the
/// queue when picked, so a queue replaced meanwhile is left alone.
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
  final choice = await showContextMenu<Object>(
    context,
    at: at,
    viaKeyboard: viaKeyboard,
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
        AppIcons.playlistRemove,
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
