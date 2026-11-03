import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/context_modal/context_modal_route.dart';
import '../../../../shared/widgets/queue_modal_footer.dart';
import 'folder_modal_actions.dart';
import 'folder_modal_advanced_page.dart';
import 'folder_modal_data.dart';
import 'folder_modal_header.dart';
import 'folder_modal_links.dart';
import 'folder_modal_session.dart';

/// The root actions page of the folder context modal: header, the navigation and
/// playback actions, and the queue buttons in the footer.
ContextModalPage folderModalActionsPage(FolderModalSession session) {
  AsyncValue<FolderStats?> statsOf(WidgetRef ref) => ref.watch(
    folderModalStatsProvider((
      path: session.folder.path,
      direct: session.direct,
    )),
  );
  return ContextModalPage(
    key: 'folder-actions',
    headerBuilder: (context, nav) => Consumer(
      builder: (context, ref, _) {
        final async = statsOf(ref);
        final data = FolderModalData(
          folder: session.folder,
          direct: session.direct,
          showFolder: session.showFolder,
          stats: async.asData?.value,
          gone: FolderModalData.goneOf(async),
        );
        final goToFolder = contextModalCloseThen(session.handlers().goToFolder);
        return FolderModalHeader(
          folder: session.folder,
          data: data,
          direct: session.direct,
          onTap: session.showFolder ? () => goToFolder(nav) : null,
        );
      },
    ),
    bodyBuilder: (context, nav) => [
      Consumer(
        builder: (context, ref, _) {
          final async = statsOf(ref);
          final data = FolderModalData(
            folder: session.folder,
            direct: session.direct,
            showFolder: session.showFolder,
            stats: async.asData?.value,
            gone: FolderModalData.goneOf(async),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(
              nav,
              folderModalSections(
                context.l10n,
                data,
                session.handlers(),
                openAdvanced: (nav) =>
                    nav.push(folderModalAdvancedPage(session)),
              ),
            ),
          );
        },
      ),
    ],
    footerBuilder: (context, nav) => Consumer(
      builder: (context, ref, _) => QueueModalFooter(
        nav: nav,
        onAction: session.queue,
        keyPrefix: 'folder-modal',
        enabled: !FolderModalData.goneOf(statsOf(ref)),
      ),
    ),
  );
}
