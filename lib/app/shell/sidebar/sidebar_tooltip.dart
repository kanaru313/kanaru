import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Space between a sidebar icon and its tooltip.
const _gap = 8.0;

/// Tooltip shown to the right of its target, vertically centered on it.
/// Used by the collapsed sidebar, where a tooltip below an icon would cover
/// the next row.
class SidebarTooltip extends StatelessWidget {
  const SidebarTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      positionDelegate: rightOfTarget,
      child: child,
    );
  }
}

/// Places the tooltip right of the target and keeps it inside the overlay
/// vertically.
@visibleForTesting
Offset rightOfTarget(TooltipPositionContext context) {
  final x = context.target.dx + context.targetSize.width / 2 + _gap;
  final y = context.target.dy - context.tooltipSize.height / 2;
  final maxY = context.overlaySize.height - context.tooltipSize.height;
  return Offset(x, maxY.isFinite ? y.clamp(0, math.max(0, maxY)) : y);
}
