import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/playlist_rows.dart';
import '../../../shared/widgets/context_modal_region.dart';
import '../../../shared/widgets/menu_keyboard_region.dart'
    show MenuKeyboardRegion;
import 'open_playlist_modal.dart';

/// Opens the playlist modal on a right click or a long press of [child], or
/// from the keyboard (Menu key, Shift+F10, see [MenuKeyboardRegion]).
class PlaylistActionsRegion extends ConsumerWidget {
  const PlaylistActionsRegion({
    super.key,
    required this.playlist,
    required this.coverKeys,
    required this.child,
    this.showGoTo = true,
    this.beforeRead,
  });

  final PlaylistSummary playlist;
  final List<String> coverKeys;
  final Widget child;

  /// False on the page of the playlist itself.
  final bool showGoTo;
  final Future<void> Function()? beforeRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContextModalRegion(
      onOpen: ({required bool viaKeyboard}) => openPlaylistModal(
        context,
        ref,
        playlist: playlist,
        coverKeys: coverKeys,
        showGoTo: showGoTo,
        viaKeyboard: viaKeyboard,
        beforeRead: beforeRead,
      ),
      child: child,
    );
  }
}
