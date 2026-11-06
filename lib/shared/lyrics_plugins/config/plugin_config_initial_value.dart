import 'package:flutter/widgets.dart';

import '../../../core/lyrics/plugins/package/plugin_config_field.dart';
import '../../../core/lyrics/plugins/store/plugin_config_values.dart';
import 'plugin_config_payload_checks.dart';
import 'plugin_config_value_messages.dart';

/// What an editor of [field] starts with: the saved value, else the
/// manifest's default (null when neither exists).
Object? pluginConfigInitialValue(
  PluginConfigField field,
  Map<String, Object?> stored,
) => stored[field.key] ?? field.defaultValue;

/// [pluginConfigInitialValue] as the text of a text box.
String pluginConfigInitialText(
  PluginConfigField field,
  Map<String, Object?> stored,
) => switch (pluginConfigInitialValue(field, stored)) {
  final String text => text,
  final num number => pluginNumberText(number),
  _ => '',
};

/// The key of the editor of [key]. It holds the record's version (an update
/// rebuilds the field from the values read for it) and the signature of the
/// choices the user added to the field, since those change the editor's list.
/// The saved value is not in the key: it goes to the editor as a parameter,
/// which shows a value written elsewhere and ignores the editor's own saves,
/// so saving never rebuilds the editor (focus and half-typed rows stay).
Key pluginConfigEditorKey(
  String installId,
  int updatedAt,
  String key,
  Map<String, Object?> stored,
) => ValueKey(
  '$installId/$updatedAt/$key'
  '/${pluginPayloadSignature(stored[pluginCustomChoicesKey(key)])}',
);
