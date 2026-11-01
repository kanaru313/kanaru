import 'package:material_ui/material_ui.dart';

/// The help text a plugin's manifest gives a config field, shown above the
/// field (it may hold newlines). Nothing when the field has none.
class PluginConfigSubtitle extends StatelessWidget {
  const PluginConfigSubtitle(this.text, {super.key});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
