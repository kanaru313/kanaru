import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/player/player_service.dart';
import '../../../../../core/player/playing_track_art.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import '../../../../../shared/widgets/context_modal/context_modal_header.dart';
import '../../../../../shared/widgets/cover_art.dart';
import '../../../../../shared/widgets/marquee_text.dart';
import 'translation_modal_navigation.dart';

/// Side of the playing track cover in the translation modal header.
const double _coverSize = 48;

/// Corner radius of the playing track cover in the translation modal header.
const double _coverRadius = 10;

/// Width reserved for the settings (`⚙`) and close (`✕`) icon buttons at the
/// trailing end of the header.
const double _trailingButtonsWidth = 96;

/// Pause before an overflowing track title or artist line starts scrolling.
const Duration _headerMarqueeDelay = Duration(milliseconds: 300);

/// Header of the lyrics translation modal: the playing track's [CoverArt],
/// its title and artist as one-line [MarqueeText] labels, a settings button
/// (`⚙`) that closes the modal and Now Playing to open Playback › Translation,
/// and a close button (`✕`).
class TranslationModalHeader extends ConsumerWidget {
  const TranslationModalHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final track = ref.watch(
      playerServiceProvider.select((s) => s.queue.current),
    );
    final cover = ref.watch(playingTrackArtProvider);
    final title = track?.title ?? '';
    final artist = track?.artist ?? '';

    return ContextModalHeader(
      leading: CoverArt(
        path: cover,
        size: _coverSize,
        radius: _coverRadius,
        placeholder: ColoredBox(
          color: colors.surfaceContainerHighest,
          child: Center(
            child: Icon(
              AppIcons.musicNoteOutlined,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
      lines: [
        MarqueeText(
          text: title,
          startDelay: _headerMarqueeDelay,
          style: theme.textTheme.titleMedium,
        ),
        if (artist.isNotEmpty)
          MarqueeText(
            text: artist,
            startDelay: _headerMarqueeDelay,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
      ],
      trailingWidth: _trailingButtonsWidth,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.lyricsTranslationMenuSettings,
            icon: const Icon(AppIcons.settingsOutlined),
            onPressed: () => openTranslationSettings(context),
          ),
          IconButton(
            tooltip: l10n.contextModalClose,
            icon: const Icon(AppIcons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
