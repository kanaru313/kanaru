import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

/// Width of [PlaylistEntryHandle]: 8 px padding around a 20 px icon.
const playlistEntryHandleWidth = 36.0;

/// The drag handle before a playlist row's cover: dragging it moves the row
/// to [index] of the enclosing reorderable list. A tap on it is swallowed so
/// a stray click does not start playback through the row's `InkWell`.
class PlaylistEntryHandle extends StatelessWidget {
  const PlaylistEntryHandle({super.key, required this.index});

  /// Position in the list as shown.
  final int index;

  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
    index: index,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Tooltip(
          message: context.l10n.playlistReorder,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(AppIcons.dragHandle, size: 20),
          ),
        ),
      ),
    ),
  );
}
