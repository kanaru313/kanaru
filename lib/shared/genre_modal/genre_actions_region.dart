import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../genre_summaries.dart';
import '../widgets/context_menu_region.dart';
import '../widgets/queue_actions_menu.dart';
import 'open_genre_modal.dart';

/// Opens the genre modal on a right click or a long press of [child], or
/// from the keyboard (Menu key, Shift+F10, see [ContextMenuRegion]). Queue
/// actions go to [onQueueAction]; the rest is carried out for [genre] by the
/// modal. Without [onQueueAction], [child] is returned as is.
class GenreActionsRegion extends ConsumerWidget {
  const GenreActionsRegion({
    super.key,
    required this.genre,
    required this.onQueueAction,
    required this.child,
    this.showGenre = true,
  });

  final GenreSummary genre;
  final ValueChanged<QueueAction>? onQueueAction;
  final Widget child;

  /// False on the page of the genre itself.
  final bool showGenre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onQueue = onQueueAction;
    return ContextMenuRegion(
      onOpen: onQueue == null
          ? null
          : ({required bool viaKeyboard, required Offset at}) =>
                openGenreModal(
                  context,
                  ref,
                  genre: genre,
                  onQueueAction: onQueue,
                  showGenre: showGenre,
                  viaKeyboard: viaKeyboard,
                ),
      child: child,
    );
  }
}
