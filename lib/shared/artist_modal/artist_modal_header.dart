import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../artist_summaries.dart';
import '../icons/app_icons.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/artist_avatar.dart';
import '../widgets/library_row.dart';

const double _avatarSize = 64;

/// Top of the artist modal: the round picture, the name and
/// "N albums • N songs • length", and the Set artist picture button (not
/// available yet). The counts come from the row the modal was opened from, so
/// they show at once; [name] is that row's until the links load, then the
/// name the artist page uses.
///
/// With [onTap] (Go to artist, which closes the modal first) the picture and
/// the text are one button that does not take keyboard focus: the first row
/// does. It is null on the page of the artist itself.
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
    Widget line(String text, TextStyle? style) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final identity = Row(
      spacing: 16,
      children: [
        ArtistAvatar(artistKey: artist.key, name: name, size: _avatarSize),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              line(name, theme.textTheme.titleMedium),
              line(details, quiet),
            ],
          ),
        ),
      ],
    );
    final tap = onTap;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 10, 12),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: tap == null
                ? identity
                : Semantics(
                    button: true,
                    hint: l10n.songModalGoToArtist,
                    child: InkWell(
                      canRequestFocus: false,
                      borderRadius: BorderRadius.circular(12),
                      onTap: tap,
                      child: identity,
                    ),
                  ),
          ),
          // Coming soon: no keyboard focus, like the coming-soon rows; the
          // hint reaches the button's own semantics node.
          MergeSemantics(
            child: Semantics(
              hint: l10n.contextModalComingSoon,
              child: ExcludeFocus(
                child: IconButton(
                  tooltip: l10n.artistModalSetPicture,
                  icon: const Icon(AppIcons.editAlbumArt),
                  color: colors.onSurfaceVariant.withValues(alpha: 0.38),
                  onPressed: () => ScaffoldMessenger.maybeOf(context)
                      ?.showSnackBar(
                        appSnackBar(
                          kind: AppSnackBarKind.info,
                          title: l10n.contextModalComingSoonSnack,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
