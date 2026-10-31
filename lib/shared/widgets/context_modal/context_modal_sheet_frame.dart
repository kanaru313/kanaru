import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// Share of the sheet's height a drag must pass to close it.
const double _closeDragFraction = 0.25;

/// Fling speed (px/s) that closes the sheet regardless of distance.
const double _closeFlingVelocity = 700;

/// Share of the screen height the sheet may take.
const double _sheetMaxHeightFraction = 0.85;

/// Narrow-window frame: a full-width bottom sheet with a drag handle. Only
/// the handle area drags, so the body keeps its own scrolling.
class ContextModalSheetFrame extends StatefulWidget {
  const ContextModalSheetFrame({
    super.key,
    required this.onClose,
    required this.child,
  });

  final VoidCallback onClose;
  final Widget child;

  @override
  State<ContextModalSheetFrame> createState() => _ContextModalSheetFrameState();
}

class _ContextModalSheetFrameState extends State<ContextModalSheetFrame> {
  double _dy = 0;
  bool _dragging = false;

  void _end(double velocity) {
    final height = context.size?.height ?? 0;
    if (_dy > height * _closeDragFraction || velocity > _closeFlingVelocity) {
      widget.onClose();
      return;
    }
    setState(() {
      _dragging = false;
      _dy = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final height = media.size.height * _sheetMaxHeightFraction;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: _dragging || reduce
            ? Duration.zero
            : const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _dy, 0),
        constraints: BoxConstraints(maxHeight: height),
        child: Material(
          color: colors.surfaceContainerHigh,
          elevation: 6,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                label: context.l10n.contextModalClose,
                onTap: widget.onClose,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => setState(() => _dragging = true),
                  onVerticalDragUpdate: (d) =>
                      setState(() => _dy = math.max(0, _dy + d.delta.dy)),
                  onVerticalDragEnd: (d) => _end(d.primaryVelocity ?? 0),
                  onVerticalDragCancel: () => setState(() {
                    _dragging = false;
                    _dy = 0;
                  }),
                  child: SizedBox(
                    height: 24,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.outline.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(child: widget.child),
              SizedBox(height: media.viewPadding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}
