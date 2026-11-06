import 'package:material_ui/material_ui.dart';

/// The inline error line of a config field that has no text box of its own
/// (a toggle, a list, a group of chips): `bodySmall` in the error color.
class PluginConfigErrorText extends StatelessWidget {
  const PluginConfigErrorText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
