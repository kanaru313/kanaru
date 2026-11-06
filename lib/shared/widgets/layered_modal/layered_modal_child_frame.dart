import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../context_modal/context_modal_sheet_frame.dart';

/// Dialog width for the first child modal (depth 1).
const double _childDialogWidth = 360;

/// Dialog width for a deeper child modal (depth 2 and above).
const double _deepChildDialogWidth = 330;

/// Maximum dialog height at depth 1 and depth >= 2.
const double _firstChildMaxHeight = 560;
const double _deeperChildMaxHeight = 480;

/// Downward offset from the window center at depth 1 and depth >= 2, so the
/// parent dialog's header stays visible behind the child.
const double _firstChildTopOffset = 28;
const double _deeperChildTopOffset = 64;

/// Maximum height fraction for a child bottom sheet, shorter than the parent's
/// 0.85 sheet so the parent stays visible behind it.
const double _childSheetMaxHeightFraction = 0.72;

/// Minimum space kept between a child dialog and the window edge.
const double _dialogMargin = 24;

/// Frame for a child modal (`depth >= 1`) stacked above a parent modal: a
/// narrower, downward-shifted `surfaceContainerHighest` dialog in wide
/// windows, or a 72% height bottom sheet in narrow ones.
class LayeredModalChildFrame extends StatelessWidget {
  const LayeredModalChildFrame({
    super.key,
    required this.depth,
    required this.isSheet,
    required this.onClose,
    required this.child,
  });

  /// Nesting level (`>= 1`); picks the dialog width and downward offset.
  final int depth;

  /// Whether to draw a bottom sheet instead of a centered dialog.
  final bool isSheet;

  /// Called by the sheet frame's close affordances.
  final VoidCallback onClose;

  /// Modal content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (isSheet) {
      return ContextModalSheetFrame(
        onClose: onClose,
        maxHeightFraction: _childSheetMaxHeightFraction,
        color: colors.surfaceContainerHighest,
        child: child,
      );
    }
    final size = MediaQuery.sizeOf(context);
    final targetWidth = depth <= 1 ? _childDialogWidth : _deepChildDialogWidth;
    final targetMaxHeight = depth <= 1
        ? _firstChildMaxHeight
        : _deeperChildMaxHeight;
    final topOffset = depth <= 1 ? _firstChildTopOffset : _deeperChildTopOffset;
    final width = math.max(
      0.0,
      math.min(targetWidth, size.width - 2 * _dialogMargin),
    );
    // The box is centered and then shifted down by topOffset, so its bottom
    // edge moves by half the height change plus the full offset: reserving
    // the offset twice keeps the bottom margin at _dialogMargin.
    final maxHeight = math.max(
      0.0,
      math.min(
        targetMaxHeight,
        size.height - 2 * _dialogMargin - 2 * topOffset,
      ),
    );
    return Center(
      child: Transform.translate(
        offset: Offset(0, topOffset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: width,
            maxWidth: width,
            maxHeight: maxHeight,
          ),
          child: Material(
            color: colors.surfaceContainerHighest,
            elevation: 8,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
