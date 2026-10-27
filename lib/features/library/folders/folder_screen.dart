import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../library_detail_body.dart';
import 'folder_library_page.dart';
import 'folders_provider.dart';

/// One folder: header, then its subfolders (with the tree on) and the songs
/// directly in it. Tapping a song plays those songs from it. [routeKey]
/// comes from the URL; a broken key or a folder without songs shows "not
/// found".
class FolderScreen extends ConsumerWidget {
  const FolderScreen({super.key, required this.routeKey});

  final String routeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = decodeFolderRouteKey(routeKey);
    return LibraryDetailBody<FolderPageData>(
      page: path == null ? null : folderPageProvider(path),
      what: 'the folder',
      notFound: const _FolderNotFound(),
      builder: (data) => LibraryFolderPage(data: data),
    );
  }
}

class _FolderNotFound extends StatelessWidget {
  const _FolderNotFound();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.navFolders,
      body: EmptyState(
        icon: AppIcons.folderOutlined,
        title: l10n.foldersNotFound,
        message: l10n.foldersNotFoundMessage,
      ),
    );
  }
}
