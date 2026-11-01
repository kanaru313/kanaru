import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/lyrics_source_routes.dart';

/// Last item of the lyrics sources list: opens the plugin store mounted under
/// the sources page, so going back returns to the same list.
class GetMorePluginsRow extends StatelessWidget {
  const GetMorePluginsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(AppIcons.download),
      title: Text(l10n.lyricsSourcesGetMore),
      subtitle: Text(l10n.lyricsSourcesGetMoreHint),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () => context.go(lyricsSourcesStoreRoute),
    );
  }
}
