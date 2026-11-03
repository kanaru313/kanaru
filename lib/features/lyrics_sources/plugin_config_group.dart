import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import 'plugin_config_error_text.dart';
import 'plugin_config_label.dart';
import 'plugin_config_subtitle.dart';

/// The frame of a config field with no text box of its own (chips, a list, a
/// map): title with its `*`, the manifest's help text, the editor, and the
/// inline error under it.
class PluginConfigGroup extends StatelessWidget {
  const PluginConfigGroup({
    super.key,
    required this.field,
    required this.child,
    this.errorText,
  });

  final PluginConfigField field;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: PluginConfigLabel(field, style: theme.textTheme.titleSmall),
        ),
        PluginConfigSubtitle(field.subtitle),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: child),
        if (errorText != null) PluginConfigErrorText(errorText!),
        const SizedBox(height: 8),
      ],
    );
  }
}
