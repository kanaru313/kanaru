import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Width of the dialog; every page has the same width.
const double contextModalDialogWidth = 400;

/// Tallest the dialog gets.
const double _dialogMaxHeight = 640;

/// Space kept between the dialog and the window edge.
const double _dialogMargin = 24;

/// Wide-window frame: a centered rounded dialog that wraps its page.
class ContextModalDialogFrame extends StatelessWidget {
  const ContextModalDialogFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: math.min(
            contextModalDialogWidth,
            size.width - 2 * _dialogMargin,
          ),
          maxWidth: math.min(
            contextModalDialogWidth,
            size.width - 2 * _dialogMargin,
          ),
          maxHeight: math.min(
            _dialogMaxHeight,
            size.height - 2 * _dialogMargin,
          ),
        ),
        child: Material(
          color: colors.surfaceContainerHigh,
          elevation: 6,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: child,
        ),
      ),
    );
  }
}
