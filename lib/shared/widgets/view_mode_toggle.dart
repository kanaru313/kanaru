import 'package:material_ui/material_ui.dart';

import '../../core/settings/library_sort.dart';
import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';

/// Header button that switches a page between cards and rows. Shows the
/// current [view]; a tap hands the other one to [onChanged].
class ViewModeToggle extends StatelessWidget {
  const ViewModeToggle({
    super.key,
    required this.view,
    required this.onChanged,
  });

  final AlbumsView view;
  final ValueChanged<AlbumsView> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: switch (view) {
        AlbumsView.grid => l10n.albumsGridView,
        AlbumsView.list => l10n.albumsListView,
      },
      icon: Icon(switch (view) {
        AlbumsView.grid => AppIcons.viewGrid,
        AlbumsView.list => AppIcons.viewList,
      }),
      onPressed: () => onChanged(switch (view) {
        AlbumsView.grid => AlbumsView.list,
        AlbumsView.list => AlbumsView.grid,
      }),
    );
  }
}
