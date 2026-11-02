import 'package:material_ui/material_ui.dart';

import '../../../shared/artist_summaries.dart';
import '../../../shared/widgets/library_grid/artist_grid_tile.dart';
import '../../../shared/widgets/library_grid/round_grid_tile.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../library_browse_body.dart';
import '../../../shared/widgets/library_grid/library_grid_delegate.dart';

/// [artists] as a scrolling grid, leaving room for the rescan button below.
class ArtistGrid extends StatelessWidget {
  const ArtistGrid({
    super.key,
    required this.artists,
    required this.onTap,
    this.onQueueAction,
  });

  final List<ArtistSummary> artists;
  final void Function(ArtistSummary artist) onTap;

  /// An action picked from the menu of [artist]; no menus without it.
  final void Function(ArtistSummary artist, QueueAction action)? onQueueAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          libraryGridPadding,
          0,
          libraryGridPadding,
          libraryBottomInset,
        ),
        gridDelegate: libraryGridDelegate(
          context,
          constraints.maxWidth - libraryGridPadding * 2,
          tileHeight: roundGridTileHeight,
        ),
        itemCount: artists.length,
        itemBuilder: (context, i) => ArtistGridTile(
          artist: artists[i],
          onTap: () => onTap(artists[i]),
          onQueueAction: onQueueAction == null
              ? null
              : (action) => onQueueAction!(artists[i], action),
        ),
      ),
    );
  }
}
