import 'package:material_ui/material_ui.dart';

import 'library_row.dart';
import 'song_tile.dart' show songCoverSize;

/// A song row whose data is still being read: the same three-line layout as
/// `SongTile` (a few pixels shorter), with bars where the texts go. [compact] matches the two-line rows of
/// [songCoverSize] instead (history).
///
/// [leadingInset] reserves an empty box of that width before the cover, so
/// the placeholder lines up with rows that start with a leading accessory (a
/// drag handle). The compact rows ignore it.
class SongTilePlaceholder extends StatelessWidget {
  const SongTilePlaceholder({
    super.key,
    this.compact = false,
    this.leadingInset = 0,
  });

  final bool compact;
  final double leadingInset;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width) => Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    Widget cover(double size) => SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
    if (compact) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 32),
        leading: cover(songCoverSize),
        title: Align(alignment: Alignment.centerLeft, child: bar(180)),
        subtitle: Align(alignment: Alignment.centerLeft, child: bar(120)),
      );
    }
    final coverBox = cover(libraryRowCoverSize);
    return LibraryRowLayout(
      leading: leadingInset > 0
          ? Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                SizedBox(width: leadingInset),
                coverBox,
              ],
            )
          : coverBox,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [bar(180), bar(120), bar(150)],
      ),
    );
  }
}
