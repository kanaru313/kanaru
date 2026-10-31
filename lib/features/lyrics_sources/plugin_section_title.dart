import 'package:material_ui/material_ui.dart';

/// Heading of a group on the plugin's page, in the style of a settings
/// section title.
class PluginSectionTitle extends StatelessWidget {
  const PluginSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
