import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/page_scaffold.dart';
import 'home_paged_list.dart';
import 'home_paged_view.dart';
import 'home_tile_metrics.dart';

/// Side padding of the grid; with the 8 px of a card it lines up with the
/// 32 px margin of the page.
const _gridPadding = 24.0;

/// A full list of cards under Home, read page by page, laid out as a grid
/// of the same cards the shelves use. Shared by the album and artist pages.
class HomeCardGridScreen<T> extends ConsumerWidget {
  const HomeCardGridScreen({
    super.key,
    required this.title,
    required this.emptyText,
    required this.emptyIcon,
    required this.pages,
    required this.cardBuilder,
    required this.cellHeight,
  });

  final String title;
  final String emptyText;
  final IconData emptyIcon;
  final NotifierProvider<HomePagedList<T>, HomePagedState<T>> pages;
  final Widget Function(T row) cardBuilder;

  /// Height of a grid cell at the current text scale.
  final double Function(BuildContext) cellHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffold(
      title: title,
      body: HomePagedView<T>(
        state: ref.watch(pages),
        onLoadMore: () => ref.read(pages.notifier).loadMore(),
        onRetry: () => ref.read(pages.notifier).retry(),
        emptyIcon: emptyIcon,
        emptyText: emptyText,
        builder: (context, controller, rows) => LayoutBuilder(
          builder: (context, constraints) {
            // Cards are a fixed width, so a cell is never narrower than one.
            final columns =
                ((constraints.maxWidth - _gridPadding * 2) / homeShelfTileWidth)
                    .floor()
                    .clamp(1, 1 << 20);
            return GridView.builder(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                _gridPadding,
                0,
                _gridPadding,
                24,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: cellHeight(context),
              ),
              itemCount: rows.length,
              itemBuilder: (context, i) => Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: homeShelfTileWidth,
                  child: cardBuilder(rows[i]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
