import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Ids of the two children [NowPlayingTabHeaderLayout] places.
enum NowPlayingTabHeaderSlot { left, dots }

/// Padding before the left button group.
const nowPlayingTabHeaderStartPadding = 8.0;

/// Least empty strip kept between the left button group and the tab dots (and
/// after the dots, before the header's end): enough room to grab the window.
const nowPlayingTabHeaderMinGap = 16.0;

/// Lays out the narrow Now Playing header: the button group at the start and
/// the tab dots centered on the window.
///
/// The window buttons that the header wrapper adds sit beside the header, so
/// the header's own center is off the window's center. The dots follow
/// [windowCenterX] (in the header's coordinates, which start at the window's
/// left edge) so they stay centered on the window. When the window is so
/// narrow that this would leave less than [nowPlayingTabHeaderMinGap] after the
/// button group, the dots move right to keep that strip, but never so far that
/// they end less than [nowPlayingTabHeaderMinGap] before the header's end,
/// unless that would push them back onto the buttons (the strip wins).
class NowPlayingTabHeaderLayout extends MultiChildLayoutDelegate {
  NowPlayingTabHeaderLayout({required this.windowCenterX});

  /// Horizontal center of the window, in the header's coordinates.
  final double windowCenterX;

  @override
  void performLayout(Size size) {
    final loose = BoxConstraints.loose(Size(size.width, size.height));
    final left = layoutChild(NowPlayingTabHeaderSlot.left, loose);
    final dots = layoutChild(NowPlayingTabHeaderSlot.dots, loose);

    positionChild(
      NowPlayingTabHeaderSlot.left,
      Offset(nowPlayingTabHeaderStartPadding, (size.height - left.height) / 2),
    );

    final minX =
        nowPlayingTabHeaderStartPadding +
        left.width +
        nowPlayingTabHeaderMinGap;
    final maxX = size.width - nowPlayingTabHeaderMinGap - dots.width;
    var x = math.max(windowCenterX - dots.width / 2, minX);
    if (x > maxX) x = math.max(maxX, minX);
    positionChild(
      NowPlayingTabHeaderSlot.dots,
      Offset(x, (size.height - dots.height) / 2),
    );
  }

  @override
  bool shouldRelayout(NowPlayingTabHeaderLayout oldDelegate) =>
      oldDelegate.windowCenterX != windowCenterX;
}
