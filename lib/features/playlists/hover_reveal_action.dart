import 'package:material_ui/material_ui.dart';

/// Tracks whether a row shows its secondary action: true while the mouse is
/// over [builder]'s whole row, or while focus is anywhere inside it (the row
/// itself or the action button).
///
/// The row decides where the action sits: [builder] gets `revealed` and wraps
/// the action in [RevealableAction].
class HoverRevealAction extends StatefulWidget {
  const HoverRevealAction({super.key, required this.builder});

  final Widget Function(BuildContext context, bool revealed) builder;

  @override
  State<HoverRevealAction> createState() => _HoverRevealActionState();
}

class _HoverRevealActionState extends State<HoverRevealAction> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    // Reports focus of the row and of the action inside it, without taking
    // a tab stop of its own.
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: widget.builder(context, _hovered || _focused),
    ),
  );
}

/// [child] while [revealed]; otherwise invisible, untouchable and hidden
/// from screen readers, but still laid out (texts do not shift) and still in
/// the focus order, so Tab can reach it and reveal it.
class RevealableAction extends StatelessWidget {
  const RevealableAction({
    super.key,
    required this.revealed,
    required this.child,
  });

  final bool revealed;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    excluding: !revealed,
    child: IgnorePointer(
      ignoring: !revealed,
      child: Opacity(opacity: revealed ? 1 : 0, child: child),
    ),
  );
}
