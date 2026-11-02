import 'package:material_ui/material_ui.dart';

import 'empty_state.dart';
import 'page_scaffold.dart';

/// Page body for a route whose item (id or key) is malformed or gone: the
/// section's [pageTitle] over an [EmptyState].
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({
    super.key,
    required this.pageTitle,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final String pageTitle;
  final IconData icon;
  final String title;
  final String message;

  /// Shown under the message.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: pageTitle,
      body: EmptyState(
        icon: icon,
        title: title,
        message: message,
        action: action,
      ),
    );
  }
}
