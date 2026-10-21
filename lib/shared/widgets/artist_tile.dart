import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'artist_avatar.dart';
import 'queue_actions_menu.dart';
import '../artist_summaries.dart';

/// One artist of the Artists list: avatar, name, "N albums · M songs".
class ArtistTile extends StatelessWidget {
  const ArtistTile({
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: ArtistAvatar(artistKey: artist.key, name: artist.name, size: 40),
      title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${l10n.artistsAlbumCount(artist.albumCount)} · '
        '${l10n.albumsSongCount(artist.songCount)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
    return QueueActionsRegion(onAction: onQueueAction, child: tile);
  }
}
