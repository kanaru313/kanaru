import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../artist_summaries.dart';
import '../widgets/context_menu_region.dart';
import '../widgets/queue_actions_menu.dart';
import 'open_artist_modal.dart';

/// Opens the artist modal on a right click or a long press of [child], or
/// from the keyboard (Menu key, Shift+F10, see [ContextMenuRegion]). Queue
/// actions go to [onQueueAction]; the rest is carried out for [artist] by the
/// modal. Without [onQueueAction], [child] is returned as is.
class ArtistActionsRegion extends ConsumerWidget {
  const ArtistActionsRegion({
    super.key,
    required this.artist,
    required this.onQueueAction,
    required this.child,
    this.showArtist = true,
  });

  final ArtistSummary artist;
  final ValueChanged<QueueAction>? onQueueAction;
  final Widget child;

  /// False on the page of the artist itself.
  final bool showArtist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onQueue = onQueueAction;
    return ContextMenuRegion(
      onOpen: onQueue == null
          ? null
          : ({required bool viaKeyboard, required Offset at}) =>
                openArtistModal(
                  context,
                  ref,
                  artist: artist,
                  onQueueAction: onQueue,
                  showArtist: showArtist,
                  viaKeyboard: viaKeyboard,
                ),
      child: child,
    );
  }
}
