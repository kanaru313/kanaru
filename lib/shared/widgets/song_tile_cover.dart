import 'package:material_ui/material_ui.dart';

import '../icons/app_icons.dart';
import 'cover_art.dart';
import 'library_row.dart';

/// Alpha of the scrim that darkens the cover of the playing row so the white
/// equalizer stays readable on any picture.
const _playingCoverScrimAlpha = 0.45;

/// The cover of a `SongTile` row. When [playing], an equalizer marks it: on
/// a real cover, white on a darkened picture; without one, the placeholder
/// itself becomes the equalizer (no music note under it). The tree has the
/// same shape either way, so a flip keeps the elements.
class SongTileCover extends StatelessWidget {
  const SongTileCover({super.key, required this.path, required this.playing});

  /// Cover file, or null for the placeholder.
  final String? path;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        CoverArt(
          path: path,
          size: libraryRowCoverSize,
          placeholder: Center(
            child: playing
                ? Icon(
                    AppIcons.equalizerRounded,
                    color: colors.onPrimaryContainer,
                  )
                : const Icon(AppIcons.musicNoteOutlined),
          ),
        ),
        if (playing && path != null) const _PlayingCoverMark(),
      ],
    );
  }
}

/// Scrim and white equalizer over a real cover. White on the darkened
/// picture is the one color outside the theme tokens (it sits on an image,
/// not on a theme surface).
class _PlayingCoverMark extends StatelessWidget {
  const _PlayingCoverMark();

  @override
  Widget build(BuildContext context) {
    final scrim = Theme.of(context).colorScheme.scrim;
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          coverArtRadius(libraryRowCoverSize),
        ),
        child: ColoredBox(
          color: scrim.withValues(alpha: _playingCoverScrimAlpha),
          child: const Center(
            child: Icon(AppIcons.equalizerRounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
