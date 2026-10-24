import 'package:material_ui/material_ui.dart';

/// Side of the cover at the start of a library list row (songs, albums).
const libraryRowCoverSize = 64.0;

/// Smallest height of a library list row: the cover plus 8 px above and
/// below. The three text lines fill exactly the cover's height.
const libraryRowMinHeight = libraryRowCoverSize + 16;

/// Joins the parts of a details line, skipping empty ones; the same dot in
/// every row.
String joinRowDetails(Iterable<String?> parts) =>
    parts.whereType<String>().where((s) => s.isNotEmpty).join(' • ');

/// The title style (semi-bold) and the details style of a library row.
({TextStyle title, TextStyle detail}) libraryRowStyles(ThemeData theme) => (
  title: theme.textTheme.bodyLarge!.copyWith(
    color: theme.colorScheme.onSurface,
    fontWeight: FontWeight.w600,
  ),
  detail: theme.textTheme.bodyMedium!.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  ),
);

/// One line of a library row, cut with an ellipsis. The strut holds the line
/// at the style's own height, so a fallback font (CJK titles) cannot make a
/// row taller than the list's prototype row.
Widget libraryRowLine(String text, TextStyle style) => Text(
  text,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: style,
  strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
);

/// [leading], then [body] taking the free width, then [trailing]. Not a
/// `ListTile`, which caps its leading at 56 px high and would squash the
/// cover.
class LibraryRowLayout extends StatelessWidget {
  const LibraryRowLayout({
    super.key,
    required this.leading,
    required this.body,
    this.trailing,
  });

  final Widget leading;
  final Widget body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: libraryRowMinHeight),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Row(
        spacing: 16,
        children: [
          leading,
          Expanded(child: body),
          ?trailing,
        ],
      ),
    ),
  );
}
