import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/context_menu_more_button.dart';
import '../../../../shared/widgets/queue_actions_menu.dart';
import '../folder_tree.dart';
import 'open_folder_modal.dart';

/// The ⋮ button of a folder tile or page: opens the folder modal. Always
/// visible, so the modal is reachable without a right click or a long press.
class FolderMoreButton extends ConsumerWidget {
  const FolderMoreButton({
    super.key,
    required this.folder,
    this.direct = false,
    required this.onQueueAction,
    this.showFolder = true,
    this.color,
  });

  final FolderNode folder;
  final bool direct;
  final ValueChanged<QueueAction> onQueueAction;
  final bool showFolder;

  /// Icon color; null keeps the theme's.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open({required bool viaKeyboard, required Offset at}) {
      openFolderModal(
        context,
        ref,
        folder: folder,
        direct: direct,
        onQueueAction: onQueueAction,
        showFolder: showFolder,
        viaKeyboard: viaKeyboard,
      );
    }

    return ContextMenuMoreButton(onOpen: open, color: color);
  }
}
