import 'package:material_ui/material_ui.dart';

/// Tile width from which the control sits beside the title. Narrower tiles
/// (or longer translations) put it under the title instead, so a wide control
/// such as a segmented button never squeezes the text or overflows.
const _inlineMinWidth = 720.0;

/// A settings row: [title] with an optional [subtitle] and a [control].
///
/// The control is on the same line when there is room and below the title
/// otherwise, shrunk to fit if it is still too wide.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    required this.control,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget control;

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
            trailing: control,
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
              FittedBox(fit: BoxFit.scaleDown, child: control),
            ],
          ),
        );
      },
    );
  }
}
