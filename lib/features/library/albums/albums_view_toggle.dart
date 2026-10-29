import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';

/// Header button that switches the album pages between a grid and rows. Shows
/// the current view; a tap switches to the other one. One setting
/// (`albumsView`) serves every page that has it.
class AlbumsViewToggle extends ConsumerWidget {
  const AlbumsViewToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(settingsProvider.select((s) => s.albumsView));
    return IconButton(
      tooltip: switch (view) {
        AlbumsView.grid => l10n.albumsGridView,
        AlbumsView.list => l10n.albumsListView,
      },
      icon: Icon(switch (view) {
        AlbumsView.grid => AppIcons.viewGrid,
        AlbumsView.list => AppIcons.viewList,
      }),
      onPressed: () =>
          ref.read(settingsProvider.notifier).setAlbumsView(switch (view) {
            AlbumsView.grid => AlbumsView.list,
            AlbumsView.list => AlbumsView.grid,
          }),
    );
  }
}
