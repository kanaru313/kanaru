import 'package:material_ui/material_ui.dart';

import '../../../core/player/track.dart';
import '../../../shared/icons/app_icons.dart';
import 'now_playing_album_line.dart';
import 'now_playing_artist_line.dart';

/// Style of the song title in [NowPlayingTitle].
TextStyle? nowPlayingTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontSize: 26, fontWeight: FontWeight.bold);

/// Title (bold, up to two lines), artist and album, as under the large cover.
class NowPlayingTitle extends StatelessWidget {
  const NowPlayingTitle({
    super.key,
    required this.track,
    this.centered = true,
    this.trailing,
    this.lineIcons = false,
  });

  final Track track;

  /// Puts a person icon before the artist and a disc icon before the album,
  /// outside their links.
  final bool lineIcons;

  /// Centers the text; otherwise it starts at the left.
  final bool centered;

  /// Placed at the end of the title line, e.g. action buttons.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final artist = track.artist;
    final title = Text(
      track.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: nowPlayingTitleStyle(context),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: [
        trailing == null
            ? title
            : Row(
                children: [
                  Expanded(child: title),
                  trailing!,
                ],
              ),
        if (artist != null) ...[
          const SizedBox(height: 8),
          NowPlayingArtistLine(
            artist: artist,
            leadingIcon: lineIcons ? AppIcons.artist : null,
          ),
        ],
        NowPlayingAlbumLine(
          centered: centered,
          leadingIcon: lineIcons ? AppIcons.album : null,
        ),
      ],
    );
  }
}
