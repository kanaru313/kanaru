import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../artist_modal/artist_actions_region.dart';
import '../../artist_summaries.dart';
import '../artist_avatar.dart';
import '../queue_actions_menu.dart';
import 'round_grid_tile.dart';

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

  /// Picked in the artist modal; no modal without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context) => ArtistActionsRegion(
    artist: artist,
    onQueueAction: onQueueAction,
    child: RoundGridTile(
      avatarBuilder: (size) =>
          ArtistAvatar(artistKey: artist.key, name: artist.name, size: size),
      title: artist.name,
      subtitle: context.l10n.albumsSongCount(artist.songCount),
      onTap: onTap,
      onQueueAction: null,
    ),
  );
}
