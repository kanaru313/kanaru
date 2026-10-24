import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'home_tile_metrics.dart';

/// A horizontal row of fixed-width cards. Round arrow buttons sit on the
/// edges while there is more to scroll in that direction; the mouse can drag
/// the row; trackpad and Shift+wheel scroll it as any horizontal list.
class HomeShelf extends StatefulWidget {
  const HomeShelf({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<HomeShelf> createState() => _HomeShelfState();
}

class _HomeShelfState extends State<HomeShelf> {
  final _controller = ScrollController();
  bool _canBack = false;
  bool _canForward = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onNotification(Notification n) {
    final ScrollMetrics? metrics = switch (n) {
      ScrollNotification() => n.metrics,
      ScrollMetricsNotification() => n.metrics,
      _ => null,
    };
    // Only the shelf's own list: a vertical page scroll bubbles up here too.
    if (metrics == null || metrics.axis != Axis.horizontal) return false;
    final back = metrics.extentBefore > 0;
    final forward = metrics.extentAfter > 0;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
    return false;
  }

  /// Scrolls 80 % of the visible width; jumps when animations are off.
  void _scrollBy(int direction) {
    final position = _controller.position;
    final target =
        (position.pixels + direction * position.viewportDimension * 0.8).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void didUpdateWidget(HomeShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A shelf that shrinks while scrolled clamps its offset without a scroll
    // notification, so read the arrows again once the new extent is laid out.
    if (oldWidget.itemCount != widget.itemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncArrows());
    }
  }

  void _syncArrows() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    if (!position.hasContentDimensions) return;
    final back = position.extentBefore > 0;
    final forward = position.extentAfter > 0;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final config = ScrollConfiguration.of(context);
    // The arrows center on the picture, not on the text below it.
    const arrowTop = homeCardPadding + homeCardPictureSize / 2 - 24;
    return SizedBox(
      height: homeShelfTileHeight(context),
      child: NotificationListener<Notification>(
        onNotification: _onNotification,
        child: Stack(
          children: [
            ScrollConfiguration(
              behavior: config.copyWith(
                scrollbars: false,
                dragDevices: {...config.dragDevices, PointerDeviceKind.mouse},
              ),
              child: ListView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                // 24 + the card's own 8 line the covers up with the title.
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemExtent: homeShelfTileWidth,
                itemCount: widget.itemCount,
                itemBuilder: widget.itemBuilder,
              ),
            ),
            if (_canBack)
              Positioned(
                left: 8,
                top: arrowTop,
                child: IconButton.filledTonal(
                  tooltip: l10n.homeScrollBack,
                  icon: const Icon(AppIcons.chevronLeft),
                  onPressed: () => _scrollBy(-1),
                ),
              ),
            if (_canForward)
              Positioned(
                right: 8,
                top: arrowTop,
                child: IconButton.filledTonal(
                  tooltip: l10n.homeScrollForward,
                  icon: const Icon(AppIcons.chevronRight),
                  onPressed: () => _scrollBy(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
