import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';

/// The title of a config field; a required one ends with a `*`.
class PluginConfigLabel extends StatelessWidget {
  const PluginConfigLabel(this.field, {super.key, this.style});

  final PluginConfigField field;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) =>
      Text(field.required ? '${field.title} *' : field.title, style: style);
}
