import 'package:material_ui/material_ui.dart';

import '../../../../shared/icons/app_icons.dart';
import '../../now_playing/now_playing_header_pill.dart';
import '../../playback_controls.dart';
import '../translation/lyrics_translation_pill.dart'
    show lyricsTranslationMinLabelWidth;

/// What the header shows for the lyrics source: the pill with [label] when
/// [room] allows one, else the round icon. [title] says where the shown
/// lyrics come from and is the pill's tooltip; the round icon uses it when
/// lyrics are [found], and [label] otherwise, as it has no text of its own.
class LyricsSourceTrigger extends StatelessWidget {
  const LyricsSourceTrigger({
    super.key,
    required this.label,
    required this.title,
    required this.found,
    required this.muted,
    required this.room,
    required this.onPressed,
  });

  final String label;
  final String title;
  final bool found;
  final bool muted;
  final double room;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (room >= lyricsTranslationMinLabelWidth) {
      return NowPlayingHeaderPill(
        icon: AppIcons.lyrics,
        label: label,
        tooltip: title,
        maxLabelWidth: room,
        muted: muted,
        onPressed: onPressed,
      );
    }
    return IconButton(
      icon: const Icon(AppIcons.lyrics),
      iconSize: playerIconSize,
      style: muted
          ? null
          : IconButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
      tooltip: found ? title : label,
      onPressed: onPressed,
    );
  }
}
