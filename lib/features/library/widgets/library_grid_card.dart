import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/song_card.dart';

/// Space between the edge of a grid cell and its card (half of the 8 px
/// between two cards).
const libraryGridCardMargin = 4.0;

/// Space between a card's edge and its cover, above and at the sides.
const libraryGridCardPadding = 4.0;

/// Space under the text of a card.
const libraryGridCardBottomPadding = 12.0;

/// Horizontal inset of the text lines inside the card padding, so text sits
/// 12 px from the card edge while the cover keeps its 4 px.
const libraryGridTextInset = 8.0;

/// Corner radius of the cover: the card's radius less its padding, so the
/// two curves are concentric.
const libraryGridCoverRadius = 8.0;

/// A grid cell's card (songs and albums): [libraryGridCardMargin] around, a
/// [songCardColor] fill, and [child] inside the card's padding. The `Material` is always present,
/// so the tree does not change when [playing] flips. [onTap] null draws no
/// ink (the placeholder).
class LibraryGridCard extends StatelessWidget {
  const LibraryGridCard({
    super.key,
    required this.child,
    this.playing = false,
    this.onTap,
  });

  final Widget child;
  final bool playing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(
        libraryGridCardPadding,
        libraryGridCardPadding,
        libraryGridCardPadding,
        libraryGridCardBottomPadding,
      ),
      child: child,
    );
    return Padding(
      padding: const EdgeInsets.all(libraryGridCardMargin),
      child: Material(
        color: songCardColor(Theme.of(context).colorScheme, playing: playing),
        shape: songCardShape,
        child: onTap == null
            ? padded
            : InkWell(onTap: onTap, customBorder: songCardShape, child: padded),
      ),
    );
  }
}
