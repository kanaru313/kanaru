import 'package:material_ui/material_ui.dart';

import '../../../core/player/track.dart';
import '../../../shared/format_duration.dart';

/// The title and artist of a queue row, stacked and centered in the space the
/// row leaves. [titleColor] `null` keeps the theme's text color.
class QueueRowText extends StatelessWidget {
  const QueueRowText({
    super.key,
    required this.track,
    this.titleColor,
    required this.artistColor,
  });

  final Track track;
  final Color? titleColor;
  final Color artistColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyLarge?.copyWith(color: titleColor),
          ),
          if (track.artist case final artist?)
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: artistColor),
            ),
        ],
      ),
    );
  }
}

/// The length of a queue row's track, in tabular figures so lengths line up;
/// nothing when the length is unknown.
class QueueRowDuration extends StatelessWidget {
  const QueueRowDuration({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final duration = track.duration;
    if (duration == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        formatDuration(duration),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
