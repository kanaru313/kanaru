import 'package:material_ui/material_ui.dart';

/// Tile width from which the control sits beside the title. Narrower tiles
/// (or longer translations) put it under the title instead and ask for a
/// compact control (a dropdown rather than a segmented button), so it never
/// squeezes the text or overflows.
const _inlineMinWidth = 720.0;

/// A settings row: [title] with an optional [subtitle] and a control built by
/// [control].
///
/// The control is on the same line when there is room. Otherwise it is built
/// compact, below the title, and shrunk to fit if it is still too wide.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    required this.control,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget Function(bool compact) control;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final subtitleText = subtitle == null ? null : Text(subtitle);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _inlineMinWidth) {
          return ListTile(
            title: Text(title),
            subtitle: subtitleText,
            trailing: control(false),
          );
        }
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyLarge),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 8),
              FittedBox(fit: BoxFit.scaleDown, child: control(true)),
            ],
          ),
        );
      },
    );
  }
}
