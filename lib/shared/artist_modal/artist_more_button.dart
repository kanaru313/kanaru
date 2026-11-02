import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../artist_summaries.dart';
import '../widgets/context_menu_more_button.dart';
import '../widgets/queue_actions_menu.dart';
import 'open_artist_modal.dart';

/// The ⋮ button at the end of an artist row: opens the artist modal. Always
/// visible, so the modal is reachable without a right click or a long press.
class ArtistMoreButton extends ConsumerWidget {
  const ArtistMoreButton({
    super.key,
    required this.artist,
    required this.onQueueAction,
    this.showArtist = true,
    this.color,
  });

  final ArtistSummary artist;
  final ValueChanged<QueueAction> onQueueAction;
  final bool showArtist;

  /// Icon color; null keeps the theme's.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open({required bool viaKeyboard, required Offset at}) =>
        openArtistModal(
          context,
          ref,
          artist: artist,
          onQueueAction: onQueueAction,
          showArtist: showArtist,
          viaKeyboard: viaKeyboard,
        );
    return ContextMenuMoreButton(onOpen: open, color: color);
  }
}
