import 'package:material_ui/material_ui.dart';

/// Room inside a menu row, and the gap between rows: the rows breathe, and
/// the tint of the row in effect is a rounded block, not a full-width band.
/// Shared by the menus Now Playing opens from its header (lyrics source,
/// translation) so they look alike.
const menuRowPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 9);

/// Style of one menu row: [menuRowPadding], rounded corners and, for the row
/// in effect, a [background] tint.
ButtonStyle menuRowStyle({Color? background}) => ButtonStyle(
  padding: const WidgetStatePropertyAll(menuRowPadding),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  backgroundColor: background == null
      ? null
      : WidgetStatePropertyAll(background),
);

/// The tint of the row in effect, from the theme's primary colour.
Color menuRowSelectedTint(ColorScheme scheme) =>
    scheme.primary.withValues(alpha: 0.14);

/// Puts the side and between-row gap around [row].
Widget menuRowSpaced(Widget row) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
  child: row,
);

/// A small capitals label that heads a group of rows.
Widget menuSectionLabel(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
  child: Semantics(
    header: true,
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
);
