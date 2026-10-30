import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/lrc_parser.dart';
import '../../core/lyrics/lyrics.dart';
import '../../core/lyrics/online/lyrics_provider.dart';
import '../../l10n/l10n.dart';

/// The lyrics of the selected result. Synced lyrics show each line's start
/// time (`mm:ss.xx`, `h:mm:ss.xx` from one hour) in a fixed-width column
/// before the text, so the timing can be judged; a wrapped line stays under
/// the text, and an empty line (an instrumental gap) shows its time with a
/// dim note. Plain lyrics, and synced text that does not parse, show the
/// text only. While the lyrics of a result that came without them are being
/// fetched it shows a progress indicator, and the sentence for the failure
/// when that failed.
class LyricsPickerPreview extends StatelessWidget {
  const LyricsPickerPreview({
    super.key,
    required this.candidate,
    this.loading = false,
    this.failure,
  });

  /// `null` when nothing is selected.
  final LyricsCandidate? candidate;

  /// The lyrics of [candidate] are being fetched.
  final bool loading;

  /// The sentence for a failed fetch of the lyrics of [candidate].
  final String? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = candidate?.body;
    if (candidate == null) return _Note(l10n.lyricsPickerNoPreview);
    if (loading) return const Center(child: CircularProgressIndicator());
    if (failure != null) return _Note(failure!);
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
    final lines = lyrics.lines;
    if (!lyrics.synced) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lines.length,
        itemBuilder: (context, i) =>
            Text(lines[i].text.isEmpty ? ' ' : lines[i].text),
      );
    }
    final hours =
        lines.fold(Duration.zero, (m, l) => l.time > m ? l.time : m) >=
        const Duration(hours: 1);
    final theme = Theme.of(context);
    final timeStyle = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // The widest time sets the column; every time has the same length.
    final painter = TextPainter(
      text: TextSpan(text: _formatTime(Duration.zero, hours), style: timeStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final column = painter.width + _timeGap;
    painter.dispose();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lines.length,
      itemBuilder: (context, i) {
        final line = lines[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: column,
              child: Text(_formatTime(line.time, hours), style: timeStyle),
            ),
            Expanded(
              child: line.text.isEmpty
                  ? Text(
                      '♪',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    )
                  : Text(line.text),
            ),
          ],
        );
      },
    );
  }
}

const _timeGap = 12.0;

/// `mm:ss.xx` (hundredths, rounded down), or `h:mm:ss.xx` when [hours].
String _formatTime(Duration d, bool hours) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final sec = d.inSeconds.remainder(60);
  final cs = d.inMilliseconds.remainder(1000) ~/ 10;
  final tail = '${two(sec)}.${two(cs)}';
  return hours ? '$h:${two(m)}:$tail' : '${two(d.inMinutes)}:$tail';
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
