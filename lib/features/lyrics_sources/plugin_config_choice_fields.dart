import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import 'plugin_config_label.dart';
import 'plugin_config_save.dart';
import 'plugin_config_subtitle.dart';

export 'plugin_config_toggle_field.dart';

/// A `select` field with one value: a dropdown of the manifest's options,
/// each with its subtitle. It saves at once; when the save fails the old
/// choice comes back and the reason shows under the box.
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
  String? _error;
  bool _saving = false;
  // What the user last picked, and what the store last accepted.
  late String? _wanted;
  late String? _saved;
  late String? _value =
      widget.field.options.any((o) => o.value == widget.initialValue)
      ? widget.initialValue
      : null;

  @override
  void initState() {
    super.initState();
    _wanted = _saved = _value;
  }

  Future<void> _choose(String? next) async {
    if (next == null || next == _value) return;
    setState(() => _value = next);
    _wanted = next;
    // One save at a time; what was picked meanwhile goes next, latest wins.
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
          // Nothing newer was picked: the old choice comes back.
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PluginConfigSubtitle(widget.field.subtitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InputDecorator(
            decoration: InputDecoration(
              label: PluginConfigLabel(widget.field),
              border: const OutlineInputBorder(),
              errorText: _error,
              errorMaxLines: 3,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _value,
                isExpanded: true,
                isDense: true,
                // The box shows the title alone; the list adds the subtitle.
                selectedItemBuilder: (_) => [
                  for (final option in widget.field.options)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(option.title),
                    ),
                ],
                items: [
                  for (final option in widget.field.options)
                    DropdownMenuItem(
                      value: option.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(option.title),
                          if (option.subtitle != null)
                            Text(
                              option.subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
                onChanged: _choose,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
