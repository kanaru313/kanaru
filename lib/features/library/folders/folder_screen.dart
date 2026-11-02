import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/library_route_keys.dart';
import '../../../shared/widgets/not_found_page.dart';
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
      notFound: NotFoundPage(
        pageTitle: context.l10n.navFolders,
        icon: AppIcons.folderOutlined,
        title: context.l10n.foldersNotFound,
        message: context.l10n.foldersNotFoundMessage,
      ),
      builder: (data) => LibraryFolderPage(data: data),
    );
  }
}
