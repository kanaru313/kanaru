import 'package:material_ui/material_ui.dart';

import 'library_row.dart';

/// Space between two song cards (half of it above and half below each card).
const songCardGap = 8.0;

/// Space between the list edge and a song card's side.
const songCardInset = 16.0;

/// Corner radius of a song card.
const songCardRadius = 12.0;

/// The rounded shape of a song card; ink effects of the row inside use it as
/// their `customBorder`.
const songCardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(songCardRadius)),
);

/// Fill of a song card: a faint veil of `onSurface` (so any page or cover
/// tint behind the list shows through), or `primaryContainer` when [playing].
/// The one place that sets the tone of the cards.
Color songCardColor(ColorScheme colors, {bool playing = false}) => playing
    ? colors.primaryContainer
    : colors.onSurface.withValues(alpha: 0.06);

/// Height of the slot of a song card: the row plus the [songCardGap]. Lists
/// of fixed-height song rows use it as their item extent.
double songCardExtent(ThemeData theme, TextScaler scaler) =>
    libraryRowExtent(theme, scaler) + songCardGap;

/// Draws [child] as a card: [songCardInset] from the sides, half of
/// [songCardGap] above and below, a [songCardColor] fill and rounded corners.
/// The `Material` is always there, so the element tree stays the same when
/// [playing] flips, and ink of the child paints over the fill. It does not
/// clip: ink follows the shape through `customBorder`.
class SongCardFrame extends StatelessWidget {
  const SongCardFrame({super.key, required this.child, this.playing = false});

  final Widget child;
  final bool playing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: songCardInset,
      vertical: songCardGap / 2,
    ),
    child: Material(
      color: songCardColor(Theme.of(context).colorScheme, playing: playing),
      shape: songCardShape,
      child: child,
    ),
  );
}
