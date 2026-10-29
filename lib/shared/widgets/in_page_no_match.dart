import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// "No songs match «query»" (or [message]), shown where a filtered list
/// would be.
class InPageNoMatch extends StatelessWidget {
  const InPageNoMatch({super.key, required this.query, this.message});

  final String query;

  /// Replaces the default text.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Text(
        message ?? context.l10n.inPageSearchNoMatch(query),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
