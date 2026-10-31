import 'package:material_ui/material_ui.dart';

import 'context_modal_nav.dart';
import 'fade_edge_scroll_view.dart';

typedef ContextModalPageBuilder = Widget Function(
  BuildContext context,
  ContextModalNav nav,
);
typedef ContextModalBodyBuilder = List<Widget> Function(
  BuildContext context,
  ContextModalNav nav,
);

/// Builds row [index] of a lazy body, only when the list asks for it.
typedef ContextModalItemBuilder = Widget Function(
  BuildContext context,
  ContextModalNav nav,
  int index,
);

/// One page of a modal: an optional fixed header, a scrolling body of tiles
/// and an optional fixed footer. The modal keeps pages on a stack, so a page
/// is pushed and popped, never replaced.
///
/// The body is either a list of widgets ([bodyBuilder], for short pages) or
/// [itemCount] rows made on demand by [itemBuilder] ([ContextModalPage.lazy],
/// for pages that may hold thousands of rows).
class ContextModalPage {
  const ContextModalPage({
    required this.key,
    required ContextModalBodyBuilder this.bodyBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.scrollController,
  }) : itemCount = null,
       itemBuilder = null;

  /// A page whose body makes a row only when the list view asks for it, so a
  /// long body costs what its visible rows cost.
  const ContextModalPage.lazy({
    required this.key,
    required int this.itemCount,
    required ContextModalItemBuilder this.itemBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.scrollController,
  }) : bodyBuilder = null;

  /// Identifies the page for the slide transition; two pages on one stack
  /// need different keys.
  final Object key;
  final ContextModalPageBuilder? headerBuilder;
  final ContextModalBodyBuilder? bodyBuilder;
  final int? itemCount;
  final ContextModalItemBuilder? itemBuilder;
  final ContextModalPageBuilder? footerBuilder;

  /// Scrolls the body when given. The modal shows only the top page, so a
  /// page below is unmounted; a controller that remembers its offset
  /// returns to it when the page is shown again.
  final ScrollController? scrollController;

  /// The page's widgets, sized to its content so the dialog wraps it.
  Widget build(BuildContext context, ContextModalNav nav) {
    final header = headerBuilder?.call(context, nav);
    final footer = footerBuilder?.call(context, nav);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?header,
        Flexible(
          child: _PageBody(page: this, nav: nav),
        ),
        ?footer,
      ],
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page, required this.nav});

  final ContextModalPage page;
  final ContextModalNav nav;

  @override
  Widget build(BuildContext context) {
    final bodyBuilder = page.bodyBuilder;
    final itemBuilder = page.itemBuilder;
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: FadeEdgeScrollView(
        controller: page.scrollController,
        builder: (controller) => bodyBuilder != null
            ? ListView(
                controller: controller,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: bodyBuilder(context, nav),
              )
            : CustomScrollView(
                controller: controller,
                shrinkWrap: true,
                slivers: [
                  SliverList.builder(
                    itemCount: page.itemCount,
                    itemBuilder: (context, i) => itemBuilder!(context, nav, i),
                  ),
                ],
              ),
      ),
    );
  }
}
