import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import 'plugin_config_save.dart';

/// A `select` field: a dropdown of the manifest's options. It saves at once;
/// when the save fails the old choice comes back.
class PluginConfigSelectField extends ConsumerStatefulWidget {
  const PluginConfigSelectField({
    super.key,
    required this.installId,
    required this.field,
    required this.initialValue,
  });

  final String installId;
  final PluginConfigField field;

  /// The saved or default option value; null shows nothing chosen.
  final String? initialValue;

  @override
  ConsumerState<PluginConfigSelectField> createState() => _SelectState();
}

class _SelectState extends ConsumerState<PluginConfigSelectField> {
  late String? _value =
      widget.field.options.any((o) => o.value == widget.initialValue)
      ? widget.initialValue
      : null;

  Future<void> _choose(String? next) async {
    if (next == null || next == _value) return;
    final before = _value;
    setState(() => _value = next);
    final ok = await savePluginConfigValue(
      context,
      ref,
      widget.installId,
      widget.field.key,
      next,
    );
    if (!ok && mounted) setState(() => _value = before);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.field.title,
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _value,
            isExpanded: true,
            isDense: true,
            items: [
              for (final option in widget.field.options)
                DropdownMenuItem(
                  value: option.value,
                  child: Text(option.title),
                ),
            ],
            onChanged: _choose,
          ),
        ),
      ),
    );
  }
}

/// A `toggle` field: a titled switch that saves at once; when the save fails
/// it flips back.
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

class _ToggleState extends ConsumerState<PluginConfigToggleField> {
  late bool _value = widget.initialValue;

  Future<void> _set(bool next) async {
    final before = _value;
    setState(() => _value = next);
    final ok = await savePluginConfigValue(
      context,
      ref,
      widget.installId,
      widget.field.key,
      next,
    );
    if (!ok && mounted) setState(() => _value = before);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(widget.field.title),
      value: _value,
      onChanged: _set,
    );
  }
}
