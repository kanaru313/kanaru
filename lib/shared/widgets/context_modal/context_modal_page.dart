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

/// One page of a modal: an optional fixed header, a scrolling body of tiles
/// and an optional fixed footer. The modal keeps pages on a stack, so a page
/// is pushed and popped, never replaced.
class ContextModalPage {
  const ContextModalPage({
    required this.key,
    required this.bodyBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.scrollController,
  });

  /// Identifies the page for the slide transition; two pages on one stack
  /// need different keys.
  final Object key;
  final ContextModalPageBuilder? headerBuilder;
  final ContextModalBodyBuilder bodyBuilder;
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
    final children = page.bodyBuilder(context, nav);
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: FadeEdgeScrollView(
        controller: page.scrollController,
        builder: (controller) => ListView(
          controller: controller,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: children,
        ),
      ),
    );
  }
}
