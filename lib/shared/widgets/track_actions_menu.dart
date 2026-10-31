import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_rows.dart';
import '../song_modal/open_song_modal.dart';
import '../song_modal/song_modal_extras.dart';
import 'menu_keyboard_region.dart';
import 'queue_actions_menu.dart';

/// Opens the song modal on a right click or a long press of [child], or from
/// the keyboard (Menu key, Shift+F10, see [MenuKeyboardRegion]). Queue
/// actions go to [onQueueAction]; the rest is carried out for [song] by the
/// modal. Without [onQueueAction], [child] is returned as is.
class TrackActionsRegion extends ConsumerWidget {
  const TrackActionsRegion({
    super.key,
    required this.song,
    required this.onQueueAction,
    required this.child,
    this.showAlbum = true,
    this.modalExtras,
  });

  final TrackListItem song;
  final ValueChanged<QueueAction>? onQueueAction;
  final Widget child;

  /// False on a page of the song's own album.
  final bool showAlbum;

  /// Screen actions and note, built when the modal opens.
  final SongModalExtrasBuilder? modalExtras;

  // Opens in the gesture handler itself: nothing is awaited first.
  void _open(
    BuildContext context,
    WidgetRef ref,
    ValueChanged<QueueAction> f, {
    bool viaKeyboard = false,
  }) => openSongModal(
    context,
    ref,
    song: song,
    onQueueAction: f,
    showAlbum: showAlbum,
    viaKeyboard: viaKeyboard,
    extras: modalExtras?.call() ?? const SongModalExtras(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onQueue = onQueueAction;
    if (onQueue == null) return child;
    return MenuKeyboardRegion(
      onOpen: (_) => _open(context, ref, onQueue, viaKeyboard: true),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (_) => _open(context, ref, onQueue),
        onLongPressStart: (_) => _open(context, ref, onQueue),
        child: child,
      ),
    );
  }
}
