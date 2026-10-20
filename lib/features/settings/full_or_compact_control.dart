import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Shows [full] at its natural size when it fits the width it is given,
/// else [compact], [compactWidth] wide (less if even that does not fit).
/// With [forceCompact], always shows [compact].
///
/// Without [compact], [full] is the only control: it is built once, and
/// narrowed to [compactWidth] when its natural width does not fit (or with
/// [forceCompact]). It is then laid out twice per layout, so it must not
/// rebuild itself after a frame just because its width changed, or it
/// would never settle.
///
/// With both, both are built and laid out, so the choice follows the actual
/// width of [full] (language, text size) within the same frame. Only the
/// chosen one is painted, hit-tested, read by accessibility services, found
/// by widget tests and, from the next frame, focusable. When the choice
/// flips, focus held in the outgoing control moves to the incoming one, and
/// the outgoing one is rebuilt from scratch, which closes any menu it had
/// open.
///
/// Changing [forceCompact] or the width given never remounts a shown
/// control, so its state (a running animation, focus, an open menu) lives
/// on.
class FullOrCompactControl extends StatefulWidget {
  const FullOrCompactControl({
    super.key,
    required this.full,
    this.compact,
    required this.compactWidth,
    this.forceCompact = false,
  });

  final Widget full;
  final Widget? compact;
  final double compactWidth;
  final bool forceCompact;

  @override
  State<FullOrCompactControl> createState() => _FullOrCompactControlState();
}

class _FullOrCompactControlState extends State<FullOrCompactControl> {
  /// Which child the last layout chose.
  bool _compact = false;

  /// The latest choice a layout reported, applied once the frame is done.
  bool _reported = false;
  bool _applyScheduled = false;

  /// Whether a choice was applied yet: the first one replaces nothing.
  bool _appliedOnce = false;

  /// Bumped when the child goes hidden, so it is rebuilt from scratch.
  int _fullGeneration = 0;
  int _compactGeneration = 0;

  // Wrap each child; hold no focus themselves, but tell whether their
  // child's subtree has it.
  final _fullFocus = FocusNode(debugLabel: 'FullOrCompactControl.full');
  final _compactFocus = FocusNode(debugLabel: 'FullOrCompactControl.compact');

  @override
  void dispose() {
    _fullFocus.dispose();
    _compactFocus.dispose();
    super.dispose();
  }

  void _chose(bool compact) {
    _reported = compact;
    if (_applyScheduled) return;
    _applyScheduled = true;
    // Reported during layout: rebuild once it is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyScheduled = false;
      final compact = _reported;
      final first = !_appliedOnce;
      _appliedOnce = true;
      if (!mounted || compact == _compact) return;
      final outgoing = compact ? _fullFocus : _compactFocus;
      final incoming = compact ? _compactFocus : _fullFocus;
      final hadFocus = outgoing.hasFocus;
      setState(() {
        _compact = compact;
        if (!first) {
          if (compact) {
            _fullGeneration++;
          } else {
            _compactGeneration++;
          }
        }
      });
      if (!hadFocus) return;
      // What the rebuild will set, done now so focus can move at once.
      outgoing.descendantsAreFocusable = false;
      incoming.descendantsAreFocusable = true;
      incoming.traversalDescendants.firstOrNull?.requestFocus();
    });
  }

  /// Keeps a hidden child out of focus, like [ExcludeFocus]. Traversal is
  /// left on: a [Focus] below would otherwise keep skipping it once shown.
  Widget _slot(FocusNode node, int generation, bool shown, Widget child) =>
      Focus(
        focusNode: node,
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        descendantsAreFocusable: shown,
        child: KeyedSubtree(key: ValueKey(generation), child: child),
      );

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    return _FullOrCompactLayout(
      compactWidth: widget.compactWidth,
      forceCompact: widget.forceCompact,
      onChosen: _chose,
      children: compact == null
          ? [widget.full]
          : [
              _slot(_fullFocus, _fullGeneration, !_compact, widget.full),
              _slot(_compactFocus, _compactGeneration, _compact, compact),
            ],
    );
  }
}

class _FullOrCompactLayout extends MultiChildRenderObjectWidget {
  const _FullOrCompactLayout({
    required this.compactWidth,
    required this.forceCompact,
    required this.onChosen,
    required super.children,
  });

  final double compactWidth;
  final bool forceCompact;
  final ValueChanged<bool> onChosen;

  @override
  MultiChildRenderObjectElement createElement() => _FullOrCompactElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFullOrCompact(compactWidth, forceCompact, onChosen);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFullOrCompact renderObject,
  ) {
    renderObject
      ..compactWidth = compactWidth
      ..forceCompact = forceCompact
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

/// Lays out one child ([full] alone, narrowed when needed) or two ([full]
/// then compact, the shown one chosen).
class _RenderFullOrCompact extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ChildParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ChildParentData> {
  _RenderFullOrCompact(this._compactWidth, this._forceCompact, this.onChosen);

  /// Told whether the compact child was chosen, when the choice changes.
  ValueChanged<bool> onChosen;

  double _compactWidth;
  set compactWidth(double value) {
    if (value == _compactWidth) return;
    _compactWidth = value;
    markNeedsLayout();
  }

  bool _forceCompact;
  set forceCompact(bool value) {
    if (value == _forceCompact) return;
    _forceCompact = value;
    markNeedsLayout();
  }

  /// The child shown since the last layout.
  RenderBox? _chosen;

  RenderBox get _full => firstChild!;

  /// The compact child; [_full] itself when it is the only one.
  RenderBox get _compact => lastChild!;

  bool get _single => childCount == 1;

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
    if (!_forceCompact) {
      final full = _full.getDryLayout(_fullConstraints(constraints));
      if (full.width <= constraints.maxWidth) {
        return constraints.constrain(full);
      }
    }
    return constraints.constrain(
      _compact.getDryLayout(_compactConstraints(constraints)),
    );
  }

  @override
  void performLayout() {
    // A hidden full child is still laid out, so it stays in a valid state.
    if (!_single || !_forceCompact) {
      _full.layout(_fullConstraints(constraints), parentUsesSize: true);
    }
    final fits = !_forceCompact && _full.size.width <= constraints.maxWidth;
    final RenderBox chosen;
    if (_single) {
      if (!fits) {
        _full.layout(_compactConstraints(constraints), parentUsesSize: true);
      }
      chosen = _full;
    } else {
      _compact.layout(_compactConstraints(constraints), parentUsesSize: true);
      chosen = fits ? _full : _compact;
    }
    if (chosen != _chosen) {
      _chosen = chosen;
      markNeedsSemanticsUpdate();
      if (!_single) onChosen(chosen == _compact);
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
