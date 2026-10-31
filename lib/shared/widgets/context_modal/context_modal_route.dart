import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import 'context_modal_page.dart';
import 'context_modal_shell.dart';

export 'context_modal_action_tile.dart';
export 'context_modal_nav.dart';
export 'context_modal_page.dart';
export 'context_modal_sections.dart';
export 'context_modal_spec.dart';
export 'context_modal_top_bar.dart';

/// Opens a context modal starting at [root]: a centered dialog in a wide
/// window, a bottom sheet in a narrow one (switching live on resize).
/// [semanticLabel] names the dialog for screen readers.
/// Completes with what `nav.close(result)` passed, or null when dismissed.
Future<T?> showContextModal<T>(
  BuildContext context, {
  required ContextModalPage root,
  String? semanticLabel,
}) {
  final reduce = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: context.l10n.contextModalClose,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: reduce
        ? Duration.zero
        : const Duration(milliseconds: 140),
    // Own messenger and transparent scaffold so snackbars of the modal's
    // actions draw above the scrim and the sheet.
    pageBuilder: (routeContext, _, _) => ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        // The scaffold takes every tap, so the dismiss area is its own layer
        // under the shell; the dialog and sheet absorb their own taps.
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(routeContext).maybePop(),
            ),
            ContextModalShell(root: root, semanticLabel: semanticLabel),
          ],
        ),
      ),
    ),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
