import 'package:material_ui/material_ui.dart';

import '../../core/player/track.dart';
import '../../shared/format_duration.dart';
import '../../shared/icons/app_icons.dart';

/// One search result: a square placeholder (no image is downloaded), the
/// title, the artist and the length when the plugin knew it.
class OnlineResultRow extends StatelessWidget {
  const OnlineResultRow({super.key, required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final artist = track.artist;
    final duration = track.duration;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 2),
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 48,
          child: ColoredBox(
            color: colors.secondaryContainer,
            child: Icon(
              AppIcons.musicNote,
              color: colors.onSecondaryContainer,
              size: 24,
            ),
          ),
        ),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: artist == null
          ? null
          : Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: duration == null ? null : Text(formatDuration(duration)),
    );
  }
}
