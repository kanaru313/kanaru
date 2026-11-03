import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';
import '../../../../shared/track_menu_actions.dart';
import '../../../../shared/widgets/context_modal/context_modal_route.dart';
import '../../../../shared/widgets/queue_actions_menu.dart';
import '../folder_tree.dart';
import 'folder_modal_actions_page.dart';
import 'folder_modal_session.dart';

/// Opens the folder modal for [folder]. Returns at once: everything the
/// actions need from [context] (router, messenger, texts) is captured here,
/// before the modal opens, and the stats load inside it.
///
/// Queue actions go to [onQueueAction], run with the `QueueHost` built from
/// what the runner captured here so they work after the row or tile is gone;
/// the rest is carried out after the modal has closed. [showFolder] false leaves
/// out Go to folder, on the page of the folder itself. [direct] indicates whether
/// the folder is shown in flat view (direct songs only) or tree view.
/// [viaKeyboard] focuses the first row.
void openFolderModal(
  BuildContext context,
  WidgetRef ref, {
  required FolderNode folder,
  required bool direct,
  required ValueChanged<QueueAction> onQueueAction,
  bool showFolder = true,
  bool viaKeyboard = false,
}) {
  final runner = TrackMenuRunner(ref, context);
  final session = FolderModalSession(
    folder: folder,
    direct: direct,
    showFolder: showFolder,
    runner: runner,
    queueHost: runner.queueHost,
    onQueueAction: onQueueAction,
    dialogContext: Navigator.maybeOf(context, rootNavigator: true)?.context,
    messenger: ScaffoldMessenger.maybeOf(context),
  );
  unawaited(
    showContextModal<void>(
      context,
      root: folderModalActionsPage(session),
      semanticLabel: context.l10n.folderModalLabel,
      viaKeyboard: viaKeyboard,
    ),
  );
}
