import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../context_modal/context_modal_dialog_frame.dart';
import '../context_modal/context_modal_frame_scope.dart';
import '../context_modal/context_modal_sheet_frame.dart';
import '../context_modal/context_modal_shell.dart';
import 'layered_modal_child_frame.dart';
import 'layered_modal_wide_frame.dart';

export 'layered_modal_body.dart';
export 'layered_modal_child_frame.dart';
export 'layered_modal_stack.dart';
export 'layered_modal_top_bar.dart';
export 'layered_modal_wide_frame.dart';

/// Nesting depth of a modal opened with [showLayeredModal]: `0` for the parent
/// modal, `1` for a child modal opened from it, `2` for a child of that child.
class LayeredModalDepth extends InheritedWidget {
  const LayeredModalDepth({
    super.key,
    required this.depth,
    required super.child,
  });

  final int depth;

  /// Depth of the enclosing layered modal, or `null` outside any modal.
  static int? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LayeredModalDepth>()?.depth;

  /// Depth of the enclosing layered modal (`0` outside any modal). Not called
  /// inside this library yet; kept public for modal content that adapts to its
  /// depth.
  static int of(BuildContext context) => maybeOf(context) ?? 0;

  /// Depth for a new modal opened from [context]: `0` when outside any layered
  /// modal, or the enclosing modal's depth plus `1`.
  static int nextOf(BuildContext context) => (maybeOf(context) ?? -1) + 1;

  @override
  bool updateShouldNotify(LayeredModalDepth oldWidget) =>
      depth != oldWidget.depth;
}

/// Opens a layered modal on the root navigator.
///
/// The nesting level is read from [LayeredModalDepth] in the caller's
/// [context]:
/// - Depth `0` (parent): 400 px [ContextModalDialogFrame] at or above
///   [contextModalSheetBelow] (600 px), [ContextModalSheetFrame] (85%) below,
///   with a 0.45 scrim.
/// - Depth `>= 1` (child stacked over the parent): [LayeredModalChildFrame]
///   (`surfaceContainerHighest`, 360 px then 330 px wide, shifted down 28 px
///   then 64 px, or a 72% bottom sheet), with a 0.35 scrim so the parent stays
///   visible underneath.
///
/// With [wide] the modal is a [LayeredModalWideFrame] instead: a centered
/// dialog sized by its content, at any depth, with no sheet variant. Depth
/// still counts, so a child of a wide modal is depth + 1.
///
/// Switches live between dialog and sheet on resize without losing the body's
/// state. Esc, a scrim tap, or the close button dismisses only the top modal.
///
/// The route has no `ScaffoldMessenger`, so a snackbar shown from inside it
/// draws under the scrim; show it after the modal closes.
Future<T?> showLayeredModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? semanticLabel,
  bool wide = false,
}) {
  final depth = LayeredModalDepth.nextOf(context);
  final reduce = MediaQuery.disableAnimationsOf(context);
  final barrierLabel = context.l10n.contextModalClose;
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: depth == 0 ? 0.45 : 0.35),
    transitionDuration: reduce
        ? Duration.zero
        : const Duration(milliseconds: 140),
    pageBuilder: (routeContext, _, _) => _LayeredModalShell(
      depth: depth,
      wide: wide,
      semanticLabel: semanticLabel,
      builder: builder,
    ),
    transitionBuilder: (_, animation, _, child) =>
        reduce ? child : FadeTransition(opacity: animation, child: child),
  );
}

class _LayeredModalShell extends StatefulWidget {
  const _LayeredModalShell({
    required this.depth,
    required this.builder,
    this.wide = false,
    this.semanticLabel,
  });

  final int depth;
  final bool wide;
  final WidgetBuilder builder;
  final String? semanticLabel;

  @override
  State<_LayeredModalShell> createState() => _LayeredModalShellState();
}

class _LayeredModalShellState extends State<_LayeredModalShell> {
  /// Preserves the modal subtree when switching between dialog and sheet frames
  /// on a window resize.
  final _contentKey = GlobalKey(debugLabel: 'LayeredModalContent');

  void _close() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final isSheet = MediaQuery.sizeOf(context).width < contextModalSheetBelow;
    final content = KeyedSubtree(
      key: _contentKey,
      child: Builder(builder: widget.builder),
    );
    final frame = widget.wide
        ? LayeredModalWideFrame(depth: widget.depth, child: content)
        : widget.depth == 0
        ? (isSheet
              ? ContextModalSheetFrame(onClose: _close, child: content)
              : ContextModalDialogFrame(child: content))
        : LayeredModalChildFrame(
            depth: widget.depth,
            isSheet: isSheet,
            onClose: _close,
            child: content,
          );
    return LayeredModalDepth(
      depth: widget.depth,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: widget.semanticLabel ?? context.l10n.contextModalLabel,
        explicitChildNodes: true,
        child: FocusTraversalGroup(
          child: ContextModalFrameScope(
            isSheet: isSheet,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                ),
                frame,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
