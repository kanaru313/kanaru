import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../artist_summaries.dart';
import '../icons/app_icons.dart';
import '../widgets/artist_avatar.dart';
import '../widgets/context_modal/context_modal_coming_soon_button.dart';
import '../widgets/context_modal/context_modal_header.dart';
import '../widgets/library_row.dart';

const double _avatarSize = 64;

/// Top of the artist modal: the round picture, the name and
/// "N albums • N songs • length", and the Set artist picture button (not
/// available yet). The counts come from the row the modal was opened from, so
/// they show at once; [name] is that row's until the links load, then the
/// name the artist page uses.
///
/// With [onTap] (Go to artist, which closes the modal first) the whole header
/// is one button that does not take keyboard focus: the first row does. It is null on the page of the artist itself.
class ArtistModalHeader extends StatelessWidget {
  const ArtistModalHeader({
    super.key,
    required this.artist,
    required this.name,
    this.onTap,
  });

  final ArtistSummary artist;
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final duration = artist.durationMs;
    final details = joinRowDetails([
      l10n.artistsAlbumCount(artist.albumCount),
      l10n.albumsSongCount(artist.songCount),
      if (duration != null) rowLength(l10n, duration),
    ]);
    return ContextModalHeader(
      leading: ArtistAvatar(
        artistKey: artist.key,
        name: name,
        size: _avatarSize,
      ),
      lines: [
        contextModalHeaderLine(name, theme.textTheme.titleMedium),
        contextModalHeaderLine(details, quiet),
      ],
      trailing: ContextModalComingSoonIconButton(
        icon: AppIcons.editAlbumArt,
        tooltip: l10n.artistModalSetPicture,
      ),
      onTap: onTap,
      tapHint: l10n.songModalGoToArtist,
    );
  }
}
