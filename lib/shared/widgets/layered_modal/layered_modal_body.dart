import 'package:material_ui/material_ui.dart';

import '../context_modal/fade_edge_scroll_view.dart';

/// Layout of a layered modal: an optional fixed [header], a scrolling list of
/// [children] with soft top/bottom edges, and an optional fixed [footer]
/// outside the scroll view (such as an action bar).
class LayeredModalBody extends StatelessWidget {
  const LayeredModalBody({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.scrollController,
  });

  /// Fixed area above the scrolling list.
  final Widget? header;

  /// Scrolling content.
  final List<Widget> children;

  /// Fixed area below the scrolling list.
  final Widget? footer;

  /// Controller of the scrolling list, for callers that scroll it.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = footer == null ? 8.0 : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?header,
        Flexible(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false),
            child: FadeEdgeScrollView(
              controller: scrollController,
              builder: (controller) => ListView(
                controller: controller,
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: bottomPadding),
                children: children,
              ),
            ),
          ),
        ),
        ?footer,
      ],
    );
  }
}
