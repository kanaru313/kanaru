import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_rows.dart';
import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../widgets/queue_actions_menu.dart';
import 'open_song_modal.dart';

/// The ⋮ button at the end of a song row: opens the song modal. Always
/// visible, so the modal is reachable without a right click or a long press.
class SongMoreButton extends ConsumerWidget {
  const SongMoreButton({
    super.key,
    required this.song,
    required this.onQueueAction,
    this.showAlbum = true,
    this.color,
  });

  final TrackListItem song;
  final ValueChanged<QueueAction> onQueueAction;
  final bool showAlbum;

  /// Icon color; null keeps the theme's.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = context.l10n.songModalMoreOptions;
    void open({required bool viaKeyboard}) => openSongModal(
      context,
      ref,
      song: song,
      onQueueAction: onQueueAction,
      showAlbum: showAlbum,
      viaKeyboard: viaKeyboard,
    );
    // Enter and Space on the focused button open the modal from the keyboard
    // (focus lands on its first row); a click does not.
    return CallbackShortcuts(
      bindings: {
        for (final key in const [
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
          LogicalKeyboardKey.space,
        ])
          SingleActivator(key): () => open(viaKeyboard: true),
      },
      child: IconButton(
        tooltip: label,
        icon: const Icon(AppIcons.more),
        iconSize: 20,
        color: color,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        onPressed: () => open(viaKeyboard: false),
      ),
    );
  }
}
