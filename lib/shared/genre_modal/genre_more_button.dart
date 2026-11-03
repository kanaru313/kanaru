import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../genre_summaries.dart';
import '../widgets/context_menu_more_button.dart';
import '../widgets/queue_actions_menu.dart';
import 'open_genre_modal.dart';

/// The ⋮ button at the end of a genre row: opens the genre modal. Always
/// visible, so the modal is reachable without a right click or a long press.
class GenreMoreButton extends ConsumerWidget {
  const GenreMoreButton({
    super.key,
    required this.genre,
    required this.onQueueAction,
    this.showGenre = true,
    this.color,
  });

  final GenreSummary genre;
  final ValueChanged<QueueAction> onQueueAction;
  final bool showGenre;

  /// Icon color; null keeps the theme's.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open({required bool viaKeyboard, required Offset at}) =>
        openGenreModal(
          context,
          ref,
          genre: genre,
          onQueueAction: onQueueAction,
          showGenre: showGenre,
          viaKeyboard: viaKeyboard,
        );
    return ContextMenuMoreButton(onOpen: open, color: color);
  }
}
