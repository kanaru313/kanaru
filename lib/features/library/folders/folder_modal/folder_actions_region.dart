import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/context_menu_region.dart';
import '../../../../shared/widgets/queue_actions_menu.dart';
import '../folder_tree.dart';
import 'open_folder_modal.dart';

/// Opens the folder modal on a right click or a long press of [child], or from
/// the keyboard (Menu key, Shift+F10, see [ContextMenuRegion]). Queue
/// actions go to [onQueueAction]; the rest is carried out for [folder] by the
/// modal. Without [onQueueAction], [child] is returned as is.
class FolderActionsRegion extends ConsumerWidget {
  const FolderActionsRegion({
    super.key,
    required this.folder,
    this.direct = false,
    required this.onQueueAction,
    this.showFolder = true,
    required this.child,
  });

  final FolderNode folder;
  final bool direct;
  final ValueChanged<QueueAction>? onQueueAction;

  /// False on the page of the folder itself.
  final bool showFolder;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onQueue = onQueueAction;
    return ContextMenuRegion(
      onOpen: onQueue == null
          ? null
          : ({required bool viaKeyboard, required Offset at}) =>
                openFolderModal(
                  context,
                  ref,
                  folder: folder,
                  direct: direct,
                  onQueueAction: onQueue,
                  showFolder: showFolder,
                  viaKeyboard: viaKeyboard,
                ),
      child: child,
    );
  }
}
