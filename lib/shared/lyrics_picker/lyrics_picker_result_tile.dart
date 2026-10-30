import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_match.dart';
import '../../core/lyrics/online/lyrics_search_controller.dart';
import '../../l10n/l10n.dart';
import '../format_duration.dart';

/// One search result: title, "artist · album", a body badge, the length
/// (with the difference to the song's when it is over the match limit) and
/// "Good match" and, for a record the user rejected before, "Rejected". A
/// result that has no lyrics and cannot get any shows dimmed and cannot be
/// selected; one that came without lyrics but can be asked for them (no
/// badge yet) is selectable.
class LyricsPickerResultTile extends StatelessWidget {
  const LyricsPickerResultTile({
    super.key,
    required this.result,
    required this.selected,
    required this.onTap,
  });

  final RankedCandidate result;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final candidate = result.candidate;
    final delta = result.match.delta;
    final duration = candidate.duration;
    final body = candidate.body;
    final badge = body == null
        ? null
        : body.syncedLrc != null
        ? l10n.lyricsPickerSynced
        : body.plain != null
        ? l10n.lyricsPickerPlain
        : body.instrumental
        ? l10n.lyricsPickerInstrumental
        : null;
    final byline = [
      candidate.artist,
      if ((candidate.album ?? '').isNotEmpty) candidate.album!,
    ].join(' · ');
    final small = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Opacity(
      opacity: !result.selectable
          ? 0.5
          : result.rejected
          ? 0.65
          : 1,
      child: ListTile(
        selected: selected,
        enabled: result.selectable,
        selectedTileColor: colors.secondaryContainer,
        selectedColor: colors.onSecondaryContainer,
        onTap: onTap,
        title: Text(
          candidate.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(byline, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (badge != null) _Badge(badge),
                if (result.rejected)
                  _Badge(
                    l10n.lyricsPickerRejected,
                    background: colors.errorContainer,
                    foreground: colors.onErrorContainer,
                  ),
                if (duration != null)
                  Text(formatDuration(duration), style: small),
                if (delta != null && delta > maxDurationDelta)
                  Text(
                    l10n.lyricsPickerDelta(
                      (delta.inMilliseconds / 1000).ceil(),
                    ),
                    style: small?.copyWith(color: colors.error),
                  ),
                if (result.match.goodMatch && !result.bodyMissing)
                  Text(
                    l10n.lyricsPickerGoodMatch,
                    style: small?.copyWith(color: colors.primary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {this.background, this.foreground});

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: foreground ?? colors.onTertiaryContainer),
        ),
      ),
    );
  }
}
