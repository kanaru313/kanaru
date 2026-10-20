import 'package:material_ui/material_ui.dart';

/// Centered icon + title + optional message, for screens with nothing to show.
///
/// Scrolls when the height it is given is too short for it (a small window
/// with large text) rather than overflowing.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Inside a column or a list: takes its own height.
        if (!constraints.hasBoundedHeight) return Center(child: content);
        return SingleChildScrollView(
          child: ConstrainedBox(
            // At least as tall as the space, so it stays centered in it.
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
