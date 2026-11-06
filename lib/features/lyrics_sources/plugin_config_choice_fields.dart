import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import '../../shared/lyrics_plugins/config/plugin_config_commit_mixin.dart';
import '../../shared/lyrics_plugins/config/plugin_config_label.dart';
import '../../shared/lyrics_plugins/config/plugin_config_subtitle.dart';

/// A `select` field with one value: a dropdown of the manifest's options,
/// each with its subtitle. It saves at once; when the save is refused the old
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

class _SelectState extends ConsumerState<PluginConfigSelectField>
    with PluginConfigCommit<PluginConfigSelectField> {
  late String? _value =
      widget.field.options.any((o) => o.value == widget.initialValue)
      ? widget.initialValue
      : null;

  @override
  PluginConfigField get commitField => widget.field;
  @override
  String get commitInstallId => widget.installId;
  // Nothing chosen is an empty string (no saved value).
  @override
  Object? get commitPayload => _value ?? '';
  @override
  bool get commitRevertsOnRefusal => true;

  @override
  void onCommitRefused(Object? lastSaved) =>
      _value = lastSaved is String && lastSaved.isNotEmpty ? lastSaved : null;

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

  void _choose(String? next) {
    if (next == null || next == _value) return;
    setState(() => _value = next);
    commit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InputDecorator(
            decoration: InputDecoration(
              label: PluginConfigLabel(widget.field),
              border: const OutlineInputBorder(),
              errorText: commitError,
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
        PluginConfigSubtitle(widget.field.subtitle),
      ],
    );
  }
}
