import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/lyrics.dart';
import '../../../l10n/l10n.dart';
import '../../icons/app_icons.dart';
import '../info/wrap_anywhere.dart';

/// Lines shown in the preview.
const _previewLines = 8;

/// More lines than this and the preview fades out and offers "View all".
const _shortLyricsLines = 6;

/// The first lines of [lyrics] and, when there are more than a few, a fade
/// and the View all button.
class LyricsPreview extends StatelessWidget {
  const LyricsPreview({
    super.key,
    required this.lyrics,
    required this.onViewAll,
  });

  final Lyrics lyrics;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(height: 1.4);
    final long = lyrics.lines.length > _shortLyricsLines;
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lyrics.lines.take(_previewLines))
          line.text.isEmpty
              ? const SizedBox(height: 8)
              : Text(wrapAnywhere(line.text), style: style),
      ],
    );
    Widget preview = lines;
    if (long) {
      final lineHeight =
          MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 14) * 1.4;
      // A fixed box clips lines that wrap, and fades the cut.
      preview = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          stops: [0, 0.6, 1],
        ).createShader(bounds),
        child: SizedBox(
          height: lineHeight * _previewLines,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: lines,
          ),
        ),
      );
    }
    final count = lyrics.lines.where((l) => l.text.isNotEmpty).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: preview,
        ),
        if (long)
          TextButton.icon(
            key: const ValueKey('song-lyrics-view-all'),
            onPressed: onViewAll,
            iconAlignment: IconAlignment.end,
            icon: const Icon(AppIcons.chevronRight),
            label: Text(context.l10n.songLyricsViewAll(count)),
          ),
      ],
    );
  }
}
