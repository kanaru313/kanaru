import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/track_lyrics_preview_provider.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../icons/app_icons.dart';
import '../../widgets/context_modal/context_modal_nav.dart';
import '../song_modal_data.dart';
import '../song_modal_session.dart';
import 'lyrics_preview.dart';
import 'lyrics_skeleton.dart';
import 'lyrics_source_chip.dart';
import 'song_lyrics_page.dart';

/// The lyrics of the song on the Song info page: where they came from, the
/// first lines and a way to the whole text. Reads only what is saved (the
/// song's own lyrics, a picked version, the online cache); it never starts
/// an online lookup. A song with none shows a card only while unknown
/// fields are shown.
class SongLyricsCard extends ConsumerWidget {
  const SongLyricsCard({
    super.key,
    required this.session,
    required this.path,
    required this.nav,
  });

  final SongModalSession session;
  final String path;
  final ContextModalNav nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(trackLyricsPreviewProvider(path));
    final showUnknown = ref.watch(
      settingsProvider.select((s) => s.display.songInfoShowUnknown),
    );
    final found = preview.asData?.value;
    final Widget body;
    if (preview.isLoading) {
      body = const _Frame(child: LyricsSkeleton());
    } else if (found != null) {
      body = _Frame(
        preview: found,
        child: LyricsPreview(
          lyrics: found.lyrics,
          onViewAll: () => nav.push(
            songLyricsPage(session, path: path, lyrics: found.lyrics),
          ),
        ),
      );
    } else if (showUnknown) {
      body = _Frame(
        child: _NoLyrics(
          onFind: session.lyricsTarget == null
              ? null
              : () => songModalCloseThen(session.handlers().findLyrics)(nav),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const ValueKey('song-lyrics-card'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: body,
    );
  }
}

/// The rounded card: heading row, then [child].
class _Frame extends StatelessWidget {
  const _Frame({required this.child, this.preview});

  final Widget child;
  final TrackLyricsPreview? preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = this.preview;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  AppIcons.lyrics,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                Text(
                  context.l10n.songLyricsTitle,
                  style: theme.textTheme.titleSmall,
                ),
                if (preview != null) LyricsSourceChip(preview: preview),
                if (preview != null && preview.lyrics.synced)
                  LyricsInfoChip(
                    label: context.l10n.songLyricsSynced,
                    highlight: true,
                  ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _NoLyrics extends StatelessWidget {
  const _NoLyrics({required this.onFind});

  final VoidCallback? onFind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.songLyricsNone,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onFind != null)
            TextButton.icon(
              key: const ValueKey('song-lyrics-find'),
              onPressed: onFind,
              icon: const Icon(AppIcons.findOnline),
              label: Text(context.l10n.songLyricsFindOnline),
            ),
        ],
      ),
    );
  }
}
