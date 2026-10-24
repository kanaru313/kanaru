import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/card_shelf.dart';
import 'home_tile_metrics.dart';

/// A row of Home cards: a [CardShelf] sized for them.
class HomeShelf extends StatelessWidget {
  const HomeShelf({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => CardShelf(
    itemCount: itemCount,
    itemBuilder: itemBuilder,
    itemExtent: homeShelfTileWidth,
    height: homeShelfTileHeight(context),
    // The arrows center on the picture, not on the text below it.
    arrowTop: homeCardPadding + homeCardPictureSize / 2 - 24,
  );
}
