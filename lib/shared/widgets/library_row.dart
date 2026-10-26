import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../fixed_line_strut.dart';
import '../icons/app_icons.dart';

/// Side of the cover at the start of a library list row (songs, albums,
/// artists).
const libraryRowCoverSize = 64.0;

/// Smallest height of a library list row: the cover plus 8 px above and
/// below. The three text lines fill exactly the cover's height.
const libraryRowMinHeight = libraryRowCoverSize + 16;

/// Height of a [LibraryRowLayout] with three lines (a title and two
/// details) at [scaler]: the lines under their struts plus 8 px above and
/// below, at least [libraryRowMinHeight]. For lists that need a row's height
/// before one is laid out. The engine rounds each line's height to whole
/// pixels (measured at scales from 1 to 2), so the function does too. Pass
/// the theme of a context ([Theme.of]), whose text theme has its sizes.
double libraryRowExtent(ThemeData theme, TextScaler scaler) {
  final styles = libraryRowStyles(theme);
  double line(TextStyle style) =>
      (scaler.scale(style.fontSize!) * (style.height ?? 1)).roundToDouble();
  return math.max(
    libraryRowMinHeight,
    16 + line(styles.title) + 2 * line(styles.detail),
  );
}

/// Joins the parts of a details line, skipping empty ones; the same dot in
/// every row.
String joinRowDetails(Iterable<String?> parts) =>
    parts.whereType<String>().where((s) => s.isNotEmpty).join(' • ');

/// [year] as text, or null when unknown (no tag, or a tag of 0).
String? rowYear(int? year) => year == null || year <= 0 ? null : '$year';

/// Whole minutes of [durationMs], at least 1 for any length above zero.
int rowMinutes(int durationMs) =>
    durationMs <= 0 ? 0 : math.max(1, (durationMs / 60000).round());

/// [durationMs] as "M min", or "H h M min" from an hour up.
String rowLength(AppLocalizations l10n, int durationMs) {
  final minutes = rowMinutes(durationMs);
  return minutes < 60
      ? l10n.albumsMinutes(minutes)
      : l10n.libraryHoursMinutes(minutes ~/ 60, minutes % 60);
}

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

/// One line of a library row, cut with an ellipsis, at a fixed height so a
/// CJK title cannot make a row taller than the list's prototype row.
Widget libraryRowLine(String text, TextStyle style) => Text(
  text,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: style,
  strutStyle: fixedLineStrut(style),
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
    this.horizontalPadding = 32,
  });

  final Widget leading;
  final Widget body;
  final Widget? trailing;

  /// Space left and right of the row.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: libraryRowMinHeight),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
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

/// A tappable library row of [leading] and three [lines] (the first one the
/// title), with a play button at its end while the row is hovered or
/// focused; no button when [onPlay] is null. The button always takes its
/// place, so the texts keep their width when it shows.
class LibraryPlayableRow extends StatefulWidget {
  const LibraryPlayableRow({
    super.key,
    required this.leading,
    required this.lines,
    required this.onTap,
    this.onPlay,
    this.playTooltip,
  });

  final Widget leading;
  final List<String> lines;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final String? playTooltip;

  @override
  State<LibraryPlayableRow> createState() => _LibraryPlayableRowState();
}

class _LibraryPlayableRowState extends State<LibraryPlayableRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final styles = libraryRowStyles(Theme.of(context));
    final onPlay = widget.onPlay;
    final showPlay = _hovered || _focused;
    return InkWell(
      onTap: widget.onTap,
      onHover: (hovered) => setState(() => _hovered = hovered),
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: LibraryRowLayout(
        leading: widget.leading,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, line) in widget.lines.indexed)
              libraryRowLine(line, i == 0 ? styles.title : styles.detail),
          ],
        ),
        // Out of the focus order: Enter on the row opens it, and the button
        // would hide again as focus left the row for it.
        trailing: onPlay == null
            ? null
            : ExcludeFocus(
                child: ExcludeSemantics(
                  excluding: !showPlay,
                  child: IgnorePointer(
                    ignoring: !showPlay,
                    child: AnimatedOpacity(
                      opacity: showPlay ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: IconButton.filledTonal(
                        icon: const Icon(AppIcons.playRounded),
                        tooltip: widget.playTooltip,
                        onPressed: onPlay,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
