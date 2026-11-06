import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/marquee_text.dart';
import 'lyrics_source_modal_run.dart';

/// Fixed bottom bar for online lyrics on screen: "Found automatically" with
/// [Not this song] and [Keep this one], or "Using the kept version" with
/// [Not this song] only. Each button closes the modal stack, then acts on the
/// lyrics the modal showed ([source]). Empty when no online lyrics show.
class LyricsSourceActionBar extends StatelessWidget {
  const LyricsSourceActionBar({
    super.key,
    required this.source,
    required this.messenger,
  });

  final LyricsSourceResolution source;
  final ScaffoldMessengerState? messenger;

  @override
  Widget build(BuildContext context) {
    final status = source.status;
    final origin = status is LyricsFound ? status.origin : null;
    if (origin == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            MarqueeText(
              text: origin.pinned
                  ? l10n.lyricsSourceBarKept
                  : l10n.lyricsSourceBarAuto,
              startDelay: const Duration(milliseconds: 300),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            // The buttons wrap under the text: both labels do not fit one line
            // in a 400 px modal.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () => closeStackThenRun(
                    context,
                    source: source,
                    messenger: messenger,
                    action: (runner) => runner.reject(),
                  ),
                  child: Text(l10n.lyricsMenuNotThese),
                ),
                if (!origin.pinned)
                  FilledButton(
                    onPressed: () => closeStackThenRun(
                      context,
                      source: source,
                      messenger: messenger,
                      action: (runner) => runner.keep(),
                    ),
                    child: Text(l10n.lyricsSourceKeep),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
