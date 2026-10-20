import 'package:material_ui/material_ui.dart';

/// Below this header width, [PageScaffold.compactActionsOf] is true and the
/// actions drop their labels to stay on the title row.
const pageHeaderCompactWidth = 640.0;

/// Layout of a top-level page: a large title (and optional subtitle) above
/// the page body, with optional [actions] at the right of the title. The app
/// bar lives in the shell, so pages don't add one.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.body,
  });

  final String title;
  final String? subtitle;

  /// Controls at the right of the title, centered on it vertically. On a
  /// narrow header they shrink to fit rather than overflow; they can read
  /// [compactActionsOf] to drop their labels first.
  final List<Widget>? actions;
  final Widget body;

  /// Whether the header of the enclosing page is narrow
  /// ([pageHeaderCompactWidth]), so its actions should be compact.
  static bool compactActionsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CompactActions>()?.compact ??
      false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = this.actions ?? const <Widget>[];
    final hasActions = actions.isNotEmpty;
    // Next to actions the title keeps to one line; alone it may wrap.
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: hasActions ? 1 : null,
          overflow: hasActions ? TextOverflow.ellipsis : null,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
          child: !hasActions
              ? heading
              : LayoutBuilder(
                  builder: (context, constraints) => _CompactActions(
                    compact: constraints.maxWidth < pageHeaderCompactWidth,
                    child: Row(
                      children: [
                        Expanded(child: heading),
                        const SizedBox(width: 16),
                        // Leaves the title some room; scales the actions
                        // down only when even their compact form is too wide.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.75,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _CompactActions extends InheritedWidget {
  const _CompactActions({required this.compact, required super.child});

  final bool compact;

  @override
  bool updateShouldNotify(_CompactActions oldWidget) =>
      compact != oldWidget.compact;
}
