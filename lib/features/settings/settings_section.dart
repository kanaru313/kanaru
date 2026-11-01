import 'package:material_ui/material_ui.dart';

/// A group of settings rows under a header. Without a [title] there is no
/// header, only a small spacer (for a page whose title already names it).
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = this.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title == null)
          const SizedBox(height: 8)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ...children,
      ],
    );
  }
}
