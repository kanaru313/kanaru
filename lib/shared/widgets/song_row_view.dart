import 'package:material_ui/material_ui.dart';

import '../format_duration.dart';
import 'library_row.dart';
import 'song_tile_cover.dart';

/// The library song row as a plain view: an optional [number] or [leading]
/// before the cover, then three lines (title, artist, [detail]), then the
/// duration above the [heart]. It reads no providers, so lists outside the
/// library (the play queue) draw the same row. [SongTile] adds the library
/// parts around it.
///
/// A [playing] row has a `primaryContainer` background, its texts in
/// `onPrimaryContainer` and an equalizer on the cover. Every line is always
/// laid out, empty or not, so all rows have the height of
/// [libraryRowExtent].
class SongRowView extends StatelessWidget {
  const SongRowView({
    super.key,
    required this.title,
    this.artist,
    this.detail = '',
    this.coverPath,
    this.duration,
    this.playing = false,
    this.onTap,
    this.number,
    this.leading,
    this.trailing,
    this.heart,
    this.badge,
    this.overlay,
    this.semanticsHint,
    this.horizontalPadding = 32,
  }) : assert(
         number == null || leading == null,
         'number and leading both fill the slot before the cover',
       );

  final String title;
  final String? artist;

  /// The third line, e.g. "album • year" (see [joinRowDetails]).
  final String detail;

  /// Local image file of the cover; null shows a music note.
  final String? coverPath;
  final Duration? duration;
  final bool playing;
  final VoidCallback? onTap;

  /// Shown right-aligned in a column before the cover; no column when null.
  final String? number;

  /// Drawn before the cover, e.g. a drag handle; replaces [number].
  final Widget? leading;

  /// Drawn after the duration and heart column, e.g. a row action.
  final Widget? trailing;

  /// Put under the duration, e.g. a `FavoriteButton`.
  final Widget? heart;

  /// Drawn at the top of the trailing column, above the duration, e.g. a
  /// listen count. The caller styles it with `labelSmall`: the column fits the
  /// row height only with that size. On a playing row the caller must pick a
  /// colour that contrasts with the `primaryContainer` fill (e.g.
  /// `onPrimaryContainer`), and it supplies its own semantics or tooltip.
  final Widget? badge;

  /// Painted over the row without taking room (a marker on its edge).
  final Widget? overlay;

  /// Read out with the row's own text, e.g. "Play next".
  final String? semanticsHint;

  /// Space left and right of the row.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final base = libraryRowStyles(theme);
    final styles = playing
        ? (
            title: base.title.copyWith(color: colors.onPrimaryContainer),
            detail: base.detail.copyWith(color: colors.onPrimaryContainer),
          )
        : base;
    final number = this.number;
    final leading = this.leading;
    final trailing = this.trailing;
    final duration = this.duration;
    final cover = SongTileCover(path: coverPath, playing: playing);

    final trailingColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ?badge,
        if (duration != null)
          Text(formatDuration(duration), style: styles.detail),
        ?heart,
      ],
    );

    // The row always has its own canvas Material (transparent when not
    // playing): ink paints under it, so the fill cannot hide hover and
    // splash, and its constant type keeps the row's elements when the
    // playing flag flips.
    Widget row = InkWell(
      onTap: onTap,
      child: LibraryRowLayout(
        horizontalPadding: horizontalPadding,
        leading: leading != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [leading, cover],
              )
            : number == null
            ? cover
            : Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      number,
                      textAlign: TextAlign.end,
                      style: styles.detail,
                    ),
                  ),
                  cover,
                ],
              ),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            libraryRowLine(title, styles.title),
            libraryRowLine(artist ?? '', styles.detail),
            libraryRowLine(detail, styles.detail),
          ],
        ),
        trailing: trailing == null
            ? trailingColumn
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [trailingColumn, trailing],
              ),
      ),
    );
    final hint = semanticsHint;
    if (hint != null) row = Semantics(hint: hint, child: row);
    final overlay = this.overlay;
    return Material(
      color: playing ? colors.primaryContainer : Colors.transparent,
      child: overlay == null
          ? row
          : Stack(
              children: [
                row,
                Positioned.fill(
                  child: IgnorePointer(child: ExcludeSemantics(child: overlay)),
                ),
              ],
            ),
    );
  }
}
