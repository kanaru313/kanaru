import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/library_grid/album_tile_data.dart';
import '../widgets/context_menu_region.dart';
import '../widgets/queue_actions_menu.dart';
import 'open_album_modal.dart';

/// Opens the album modal on a right click or a long press of [child], or from
/// the keyboard (Menu key, Shift+F10, see [ContextMenuRegion]). Queue
/// actions go to [onQueueAction]; the rest is carried out for [album] by the
/// modal. Without [onQueueAction], [child] is returned as is.
class AlbumActionsRegion extends ConsumerWidget {
  const AlbumActionsRegion({
    super.key,
    required this.album,
    required this.onQueueAction,
    required this.child,
    this.showAlbum = true,
  });

  final AlbumTileData album;
  final ValueChanged<QueueAction>? onQueueAction;
  final Widget child;

  /// False on the page of the album itself.
  final bool showAlbum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onQueue = onQueueAction;
    return ContextMenuRegion(
      onOpen: onQueue == null
          ? null
          : ({required bool viaKeyboard, required Offset at}) => openAlbumModal(
              context,
              ref,
              album: album,
              onQueueAction: onQueue,
              showAlbum: showAlbum,
              viaKeyboard: viaKeyboard,
            ),
      child: child,
    );
  }
}
