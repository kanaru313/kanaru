import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/lyrics_plugins/config/plugin_config_commit_mixin.dart';
import '../../shared/lyrics_plugins/config/plugin_config_payload_checks.dart';
import '../../shared/lyrics_plugins/config/plugin_config_value_messages.dart';
import 'plugin_config_group.dart';
import 'plugin_config_row_box.dart';

/// A `list` field: one text box per item (text, number, integer or url), with
/// Add (off at the item limit) and a Remove button per row. The whole list is
/// saved when a row is left or removed; empty rows are not part of it.
class PluginConfigListField extends ConsumerStatefulWidget {
  const PluginConfigListField({
    super.key,
    required this.installId,
    required this.field,
    required this.initialItems,
  });

  final String installId;
  final PluginConfigField field;

  /// The saved or default items: strings, or numbers for a number list.
  final List<Object?> initialItems;

  @override
  ConsumerState<PluginConfigListField> createState() => _State();
}

class _State extends ConsumerState<PluginConfigListField>
    with PluginConfigCommit<PluginConfigListField> {
  late final List<PluginConfigRowBox> _rows = [
    for (final item in widget.initialItems)
      _newRow(item is num ? pluginNumberText(item) : '$item'),
  ];

  PluginListFormat get _format =>
      widget.field.listFormat ?? PluginListFormat.text;
  int get _limit => widget.field.maxItems ?? pluginConfigMaxItems;

  @override
  PluginConfigField get commitField => widget.field;
  @override
  String get commitInstallId => widget.installId;

  /// The non-empty rows, typed by the list's format; text that does not
  /// parse stays a string so the value check reports it.
  @override
  Object? get commitPayload => [
    for (final row in _rows)
      if (row.text.trim().isNotEmpty) _typed(row.text),
  ];

  Object _typed(String text) => switch (_format) {
    PluginListFormat.number => pluginParseFinite(text) ?? text,
    PluginListFormat.integer => pluginParseFinite(text, whole: true) ?? text,
    _ => text,
  };

  PluginConfigRowBox _newRow(String text) =>
      PluginConfigRowBox(text, onBlur: commitOnBlur);

  @override
  void initState() {
    super.initState();
    commitStart(commitPayload);
  }

  @override
  void dispose() {
    commitTeardown();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _add() {
    final row = _newRow('');
    setState(() => _rows.add(row));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) row.focus.requestFocus();
    });
  }

  void _remove(PluginConfigRowBox row) {
    setState(() => _rows.remove(row));
    // The row's box is still in this frame's tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
    commit();
  }

  TextInputType get _keyboard => switch (_format) {
    PluginListFormat.url => TextInputType.url,
    PluginListFormat.number => const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    PluginListFormat.integer => const TextInputType.numberWithOptions(
      signed: true,
    ),
    PluginListFormat.text => TextInputType.text,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PluginConfigGroup(
      field: widget.field,
      errorText: commitError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _rows.length; i++)
            Padding(
              key: ObjectKey(_rows[i]),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: l10n.pluginConfigListRowLabel(
                        widget.field.title,
                        i + 1,
                      ),
                      child: TextField(
                        controller: _rows[i].controller,
                        focusNode: _rows[i].focus,
                        keyboardType: _keyboard,
                        inputFormatters: [
                          if (_format == PluginListFormat.number)
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[-+0-9.eE]'),
                            ),
                          if (_format == PluginListFormat.integer)
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[-+0-9]'),
                            ),
                        ],
                        onChanged: (_) => commitChanged(),
                        onSubmitted: (_) => commit(),
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          hintText: widget.field.placeholder,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.pluginConfigRemoveItem,
                    icon: const Icon(AppIcons.closeRounded),
                    onPressed: () => _remove(_rows[i]),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: _rows.length >= _limit ? null : _add,
            icon: const Icon(AppIcons.add),
            label: Text(l10n.pluginConfigAddItem),
          ),
        ],
      ),
    );
  }
}
