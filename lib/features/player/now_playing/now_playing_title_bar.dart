import 'package:material_ui/material_ui.dart';

/// Wraps a Now Playing header button so pressing it never starts a window
/// drag or counts towards a maximizing double click.
typedef NowPlayingDragExclusion = Widget Function(Widget button);

/// Wraps the header in the window's drag area and buttons, and marks its
/// buttons as interactive within that area. Both live in the app shell, which
/// features cannot reach; they come together so one cannot be given without
/// the other.
class NowPlayingTitleBar {
  const NowPlayingTitleBar({
    required this.wrapHeader,
    required this.excludeFromDrag,
  });

  /// Adds the drag area and window buttons around the header.
  final Widget Function(Widget header) wrapHeader;

  /// Wraps each header button, see [NowPlayingDragExclusion].
  final NowPlayingDragExclusion excludeFromDrag;
}

/// Stand-in without a title bar: [button] unchanged.
Widget noDragExclusion(Widget button) => button;
