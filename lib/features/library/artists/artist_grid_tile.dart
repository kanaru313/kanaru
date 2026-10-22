import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/artist_summaries.dart';
import '../../../shared/widgets/artist_avatar.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../albums/album_grid_tile.dart';
import '../widgets/library_rescan_button.dart';
import '../widgets/round_grid_tile.dart';

/// One artist in a grid: round avatar, name, "N songs".
class ArtistGridTile extends StatelessWidget {
  const ArtistGridTile({
    super.key,
    required this.artist,
    required this.onTap,
    this.onQueueAction,
  });

  final ArtistSummary artist;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context) => RoundGridTile(
    avatarBuilder: (size) =>
        ArtistAvatar(artistKey: artist.key, name: artist.name, size: size),
    title: artist.name,
    subtitle: context.l10n.albumsSongCount(artist.songCount),
    onTap: onTap,
    onQueueAction: onQueueAction,
  );
}

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
          albumGridPadding,
          0,
          albumGridPadding,
          libraryRescanClearance,
        ),
        gridDelegate: libraryGridDelegate(
          context,
          constraints.maxWidth - albumGridPadding * 2,
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
