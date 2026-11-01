import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/context_modal_more_button.dart';
import '../widgets/library_grid/album_tile_data.dart';
import '../widgets/queue_actions_menu.dart';
import 'open_album_modal.dart';

/// The ⋮ button at the end of an album row: opens the album modal. Always
/// visible, so the modal is reachable without a right click or a long press.
class AlbumMoreButton extends ConsumerWidget {
  const AlbumMoreButton({
    super.key,
    required this.album,
    required this.onQueueAction,
    this.showAlbum = true,
    this.color,
  });

  final AlbumTileData album;
  final ValueChanged<QueueAction> onQueueAction;
  final bool showAlbum;

  /// Icon color; null keeps the theme's.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open({required bool viaKeyboard}) => openAlbumModal(
      context,
      ref,
      album: album,
      onQueueAction: onQueueAction,
      showAlbum: showAlbum,
      viaKeyboard: viaKeyboard,
    );
    return ContextModalMoreButton(onOpen: open, color: color);
  }
}
