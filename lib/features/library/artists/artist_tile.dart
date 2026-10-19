import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../widgets/artist_avatar.dart';
import 'artist_summaries.dart';

/// One artist of the Artists list: avatar, name, "N albums · M songs".
class ArtistTile extends StatelessWidget {
  const ArtistTile({super.key, required this.artist, required this.onTap});

  final ArtistSummary artist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
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
  }
}
