import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import 'plugin_config_error_text.dart';
import 'plugin_config_save.dart';

/// A `toggle` field: a titled switch that saves at once; when the save fails
/// it flips back and the reason shows under it.
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
  // What the user last chose, and what the store last accepted.
  late bool _wanted;
  late bool _saved;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _wanted = _saved = _value;
  }

  Future<void> _set(bool next) async {
    if (next == _value) return;
    setState(() => _value = next);
    _wanted = next;
    // One save at a time; the latest switch position goes last.
    if (_saving) return;
    _saving = true;
    try {
      while (mounted && _wanted != _saved) {
        final target = _wanted;
        final result = await savePluginConfigValue(
          context,
          ref,
          widget.installId,
          widget.field.key,
          target,
        );
        if (!mounted) return;
        if (result.saved) {
          _saved = target;
          setState(() => _error = null);
        } else if (_wanted == target) {
          _wanted = _saved;
          setState(() {
            _error = result.message;
            _value = _saved;
          });
        }
      }
    } finally {
      _saving = false;
    }
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
        if (_error != null) PluginConfigErrorText(_error!),
      ],
    );
  }
}
