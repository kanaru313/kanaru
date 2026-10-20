import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Shows [full] at its natural size when it fits the width it is given,
/// else [compact], [compactWidth] wide (less if even that does not fit).
///
/// Both are built and laid out, so the choice follows the actual width of
/// [full] (language, text size) within the same frame. Only the chosen one
/// is painted, hit-tested, read by accessibility services, found by widget
/// tests and, from the next frame, focusable.
class FullOrCompactControl extends StatefulWidget {
  const FullOrCompactControl({
    super.key,
    required this.full,
    required this.compact,
    required this.compactWidth,
  });

  final Widget full;
  final Widget compact;
  final double compactWidth;

  @override
  State<FullOrCompactControl> createState() => _FullOrCompactControlState();
}

class _FullOrCompactControlState extends State<FullOrCompactControl> {
  /// Which child the last layout chose; keeps the other out of focus.
  bool _compact = false;

  void _chose(bool compact) {
    if (compact == _compact) return;
    // Reported during layout: rebuild once it is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && compact != _compact) setState(() => _compact = compact);
    });
  }

  @override
  Widget build(BuildContext context) => _FullOrCompactLayout(
    compactWidth: widget.compactWidth,
    onChosen: _chose,
    children: [
      ExcludeFocus(excluding: _compact, child: widget.full),
      ExcludeFocus(excluding: !_compact, child: widget.compact),
    ],
  );
}

class _FullOrCompactLayout extends MultiChildRenderObjectWidget {
  const _FullOrCompactLayout({
    required this.compactWidth,
    required this.onChosen,
    required super.children,
  });

  final double compactWidth;
  final ValueChanged<bool> onChosen;

  @override
  MultiChildRenderObjectElement createElement() => _FullOrCompactElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFullOrCompact(compactWidth, onChosen);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFullOrCompact renderObject,
  ) {
    renderObject
      ..compactWidth = compactWidth
      ..onChosen = onChosen;
  }
}

class _FullOrCompactElement extends MultiChildRenderObjectElement {
  _FullOrCompactElement(super.widget);

  // Widget finders see only the control on screen.
  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final chosen = (renderObject as _RenderFullOrCompact)._chosen;
    for (final child in children) {
      if (child.renderObject == chosen) visitor(child);
    }
  }
}

class _ChildParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFullOrCompact extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ChildParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ChildParentData> {
  _RenderFullOrCompact(this._compactWidth, this.onChosen);

  /// Told whether the compact child was chosen, when the choice changes.
  ValueChanged<bool> onChosen;

  double _compactWidth;
  set compactWidth(double value) {
    if (value == _compactWidth) return;
    _compactWidth = value;
    markNeedsLayout();
  }

  /// The child shown since the last layout.
  RenderBox? _chosen;

  RenderBox get _full => firstChild!;
  RenderBox get _compact => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ChildParentData) {
      child.parentData = _ChildParentData();
    }
  }

  /// Unbounded width, so [_full] reports its natural width.
  BoxConstraints _fullConstraints(BoxConstraints constraints) =>
      BoxConstraints(maxHeight: constraints.maxHeight);

  BoxConstraints _compactConstraints(BoxConstraints constraints) => constraints
      .loosen()
      .tighten(width: math.min(_compactWidth, constraints.maxWidth));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final full = _full.getDryLayout(_fullConstraints(constraints));
    if (full.width <= constraints.maxWidth) return constraints.constrain(full);
    return constraints.constrain(
      _compact.getDryLayout(_compactConstraints(constraints)),
    );
  }

  @override
  void performLayout() {
    _full.layout(_fullConstraints(constraints), parentUsesSize: true);
    _compact.layout(_compactConstraints(constraints), parentUsesSize: true);
    final chosen = _full.size.width <= constraints.maxWidth ? _full : _compact;
    if (chosen != _chosen) {
      _chosen = chosen;
      markNeedsSemanticsUpdate();
      onChosen(chosen == _compact);
    }
    size = constraints.constrain(chosen.size);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _compact.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _full.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      (_chosen ?? _full).getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      (_chosen ?? _full).getMaxIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _chosen?.getDistanceToActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) {
    final chosen = _chosen;
    if (chosen != null) context.paintChild(chosen, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      _chosen?.hitTest(result, position: position) ?? false;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final chosen = _chosen;
    if (chosen != null) visitor(chosen);
  }
}
