import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/plugins/package/plugin_manifest.dart';
import 'plugin_config_commit_mixin.dart';
import 'plugin_config_error_text.dart';
import 'plugin_config_flush_group.dart';

/// A `toggle` field: a titled switch that saves at once; when the save is
/// refused it flips back and the reason shows under it.
class PluginConfigToggleField extends ConsumerStatefulWidget {
  const PluginConfigToggleField({
    super.key,
    required this.installId,
    required this.field,
    required this.initialValue,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.forgetsFailures = true,
    this.flushGroup,
  });

  final String installId;
  final PluginConfigField field;
  final bool initialValue;

  /// Space left and right of the row.
  final EdgeInsetsGeometry padding;

  /// Whether a saved value makes the failed translations of the plugin start
  /// over (see [PluginConfigCommit.commitForgetsFailures]).
  final bool forgetsFailures;

  /// The group that saves this switch together with others, if any.
  final PluginConfigFlushGroup? flushGroup;

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
  bool get commitForgetsFailures => widget.forgetsFailures;
  @override
  PluginConfigFlushGroup? get commitFlushGroup => widget.flushGroup;
  @override
  Object? get commitPayload => _value;
  @override
  bool get commitRevertsOnRefusal => true;

  @override
  void didUpdateWidget(PluginConfigToggleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    commitExternal(widget.initialValue);
  }

  @override
  void onExternalValue(Object? payload) => _value = payload == true;

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
          contentPadding: widget.padding,
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
