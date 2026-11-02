import 'package:material_ui/material_ui.dart';

/// The description of a playlist in at most [maxLines] lines tall; longer
/// text scrolls inside without a visible scrollbar. Draws nothing when
/// [text] is empty.
class PlaylistDescriptionBox extends StatelessWidget {
  const PlaylistDescriptionBox({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 2,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final base = style ?? Theme.of(context).textTheme.bodySmall;
    final fontSize = base?.fontSize ?? 12;
    // Line height as the text lays out: font size times the style's height
    // factor, scaled like the text itself.
    final line =
        MediaQuery.textScalerOf(context).scale(fontSize) *
        (base?.height ?? 1.3);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: line * maxLines),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          child: Text(
            text,
            key: const ValueKey('playlist-description-text'),
            style: base?.copyWith(height: base.height ?? 1.3),
          ),
        ),
      ),
    );
  }
}
