import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import 'plugin_config_commit_mixin.dart';
import 'plugin_config_error_text.dart';

/// A `toggle` field: a titled switch that saves at once; when the save is
/// refused it flips back and the reason shows under it.
class PluginConfigToggleField extends ConsumerStatefulWidget {
  const PluginConfigToggleField({
    super.key,
    required this.installId,
    required this.field,
    required this.initialValue,
  });

  final String installId;
  final PluginConfigField field;
  final bool initialValue;

  @override
  ConsumerState<PluginConfigToggleField> createState() => _ToggleState();
}

class _ToggleState extends ConsumerState<PluginConfigToggleField>
    with PluginConfigCommit<PluginConfigToggleField> {
  late bool _value = widget.initialValue;

  @override
  PluginConfigField get commitField => widget.field;
  @override
  String get commitInstallId => widget.installId;
  @override
  Object? get commitPayload => _value;
  @override
  bool get commitRevertsOnRefusal => true;

  @override
  void onCommitRefused(Object? lastSaved) => _value = lastSaved == true;

  @override
  void initState() {
    super.initState();
    commitStart(_value);
  }

  @override
  void dispose() {
    commitTeardown();
    super.dispose();
  }

  void _set(bool next) {
    if (next == _value) return;
    setState(() => _value = next);
    commit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(widget.field.title),
          subtitle: widget.field.subtitle == null
              ? null
              : Text(widget.field.subtitle!),
          value: _value,
          onChanged: _set,
        ),
        if (commitError != null) PluginConfigErrorText(commitError!),
      ],
    );
  }
}
