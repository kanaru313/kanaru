import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/lrc_parser.dart';
import '../../core/lyrics/lyrics.dart';
import '../../core/lyrics/online/lyrics_provider.dart';
import '../../l10n/l10n.dart';

/// The lyrics of the selected result as plain lines: synced lyrics are shown
/// without their time tags.
class LyricsPickerPreview extends StatelessWidget {
  const LyricsPickerPreview({super.key, required this.candidate});

  /// `null` when nothing is selected.
  final LyricsCandidate? candidate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = candidate?.body;
    if (candidate == null) return _Note(l10n.lyricsPickerNoPreview);
    if (body == null) return _Note(l10n.lyricsPickerNoBody);
    // Synced text that does not parse falls back to the plain text.
    final lyrics = [body.syncedLrc, body.plain].nonNulls
        .map((t) => parseLyricsText(t, LyricsSource.sidecar))
        .nonNulls
        .firstOrNull;
    if (lyrics == null) {
      return _Note(
        body.instrumental
            ? l10n.lyricsPickerInstrumentalPreview
            : l10n.lyricsPickerNoBody,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, i) {
        final line = lyrics.lines[i].text;
        return Text(line.isEmpty ? ' ' : line);
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}
