import 'package:material_ui/material_ui.dart';

/// Downward offset of a wide modal stacked over another modal, so the parent's
/// header stays visible behind it.
const double _stackedTopOffset = 28;

/// Frame for a wide layered modal: a centered dialog surface sized by its
/// [child] (the modal fixes its own width and height). Stacked over another
/// modal (`depth >= 1`) it is shifted down like [LayeredModalChildFrame]. It
/// has no sheet variant.
class LayeredModalWideFrame extends StatelessWidget {
  const LayeredModalWideFrame({
    super.key,
    required this.depth,
    required this.child,
  });

  /// Nesting level; `0` is not shifted.
  final int depth;

  /// Modal content.
  final Widget child;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(0, depth >= 1 ? _stackedTopOffset : 0),
    child: Dialog(child: child),
  );
}
