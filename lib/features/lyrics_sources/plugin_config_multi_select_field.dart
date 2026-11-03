import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import 'plugin_config_commit_mixin.dart';
import 'plugin_config_group.dart';

/// A `select` field with `multiple` values: one `FilterChip` per option. Each
/// toggle saves the whole choice (in the manifest's option order); a choice
/// outside the item limits shows its error under the chips and is not saved.
class PluginConfigMultiSelectField extends ConsumerStatefulWidget {
  const PluginConfigMultiSelectField({
    super.key,
    required this.installId,
    required this.field,
    required this.initialValues,
  });

  final String installId;
  final PluginConfigField field;

  /// The saved or default option values.
  final List<String> initialValues;

  @override
  ConsumerState<PluginConfigMultiSelectField> createState() => _State();
}

class _State extends ConsumerState<PluginConfigMultiSelectField>
    with PluginConfigCommit<PluginConfigMultiSelectField> {
  late final Set<String> _chosen = {
    for (final option in widget.field.options)
      if (widget.initialValues.contains(option.value)) option.value,
  };

  @override
  PluginConfigField get commitField => widget.field;
  @override
  String get commitInstallId => widget.installId;
  @override
  Object? get commitPayload => [
    for (final option in widget.field.options)
      if (_chosen.contains(option.value)) option.value,
  ];

  @override
  void initState() {
    super.initState();
    commitStart(commitPayload);
  }

  @override
  void dispose() {
    commitTeardown();
    super.dispose();
  }

  void _toggle(String value, bool on) {
    setState(() => on ? _chosen.add(value) : _chosen.remove(value));
    commit();
  }

  @override
  Widget build(BuildContext context) {
    return PluginConfigGroup(
      field: widget.field,
      errorText: commitError,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final option in widget.field.options) _chip(option)],
      ),
    );
  }

  Widget _chip(PluginConfigOption option) {
    final chip = FilterChip(
      label: Text(option.title),
      selected: _chosen.contains(option.value),
      onSelected: (on) => _toggle(option.value, on),
    );
    final subtitle = option.subtitle;
    return subtitle == null ? chip : Tooltip(message: subtitle, child: chip);
  }
}
