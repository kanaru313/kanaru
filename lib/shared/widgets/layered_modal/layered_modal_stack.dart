import 'package:material_ui/material_ui.dart';

/// Closes the modal route containing [modalContext] and every modal route
/// stacked above it (such as a child selection picker or a consent dialog).
///
/// Does nothing when [modalContext] is not inside an active [PopupRoute], so
/// a page route underneath the modal is never popped by mistake.
void closeLayeredModalStack(BuildContext modalContext) {
  if (!modalContext.mounted) return;
  final route = ModalRoute.of(modalContext);
  if (route is! PopupRoute || !route.isActive) return;
  final navigator = Navigator.of(modalContext);
  navigator.popUntil((r) => r == route);
  if (route.isActive) {
    navigator.pop();
  }
}
