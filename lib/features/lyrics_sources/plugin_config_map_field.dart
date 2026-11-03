import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/package/plugin_manifest.dart';
import '../../core/lyrics/plugins/store/plugin_config_value_rules.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'plugin_config_commit_mixin.dart';
import 'plugin_config_group.dart';
import 'plugin_config_row_box.dart';

/// One row of a map editor: a key box and a value box.
class _Row {
  _Row(String key, String value, VoidCallback onBlur)
    : key = PluginConfigRowBox(key, onBlur: onBlur),
      value = PluginConfigRowBox(value, onBlur: onBlur);

  final PluginConfigRowBox key;
  final PluginConfigRowBox value;

  bool get isBlank => key.text.isEmpty && value.text.isEmpty;

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

/// A `map` field: rows of a name and a value, with Add (off at the entry
/// limit) and a Remove button per row. The map is saved when a row is left or
/// removed. A name that is not valid, or that an earlier row uses, shows its
/// error on that row, and the map is not saved until it is fixed. Blank rows
/// are not part of the map.
class PluginConfigMapField extends ConsumerStatefulWidget {
  const PluginConfigMapField({
    super.key,
    required this.installId,
    required this.field,
    required this.initialEntries,
  });

  final String installId;
  final PluginConfigField field;

  /// The saved or default entries.
  final Map<String, String> initialEntries;

  @override
  ConsumerState<PluginConfigMapField> createState() => _State();
}

class _State extends ConsumerState<PluginConfigMapField>
    with PluginConfigCommit<PluginConfigMapField> {
  late final List<_Row> _rows = [
    for (final e in widget.initialEntries.entries) _newRow(e.key, e.value),
  ];

  int get _limit => widget.field.maxItems ?? pluginConfigMaxItems;

  @override
  PluginConfigField get commitField => widget.field;
  @override
  String get commitInstallId => widget.installId;

  /// The rows that are not blank; a repeated name keeps the first row's value
  /// (the rows show the error and nothing is saved meanwhile).
  @override
  Object? get commitPayload {
    final out = <String, String>{};
    for (final row in _rows) {
      if (!row.isBlank) out.putIfAbsent(row.key.text, () => row.value.text);
    }
    return out;
  }

  _Row _newRow(String key, String value) => _Row(key, value, commitOnBlur);

  /// What is wrong with the name of the row at [index], or null.
  String? _keyError(int index) {
    final row = _rows[index];
    if (row.isBlank) return null;
    final l10n = context.l10n;
    if (!pluginMapKeyIsValid(row.key.text)) return l10n.pluginConfigKeyInvalid;
    final taken = _rows
        .take(index)
        .any((other) => !other.isBlank && other.key.text == row.key.text);
    return taken ? l10n.pluginConfigKeyDuplicate : null;
  }

  @override
  String? commitProblem(AppLocalizations l10n, Object? payload) {
    for (var i = 0; i < _rows.length; i++) {
      final error = _keyError(i);
      if (error != null) return error;
    }
    return null;
  }

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
    final row = _newRow('', '');
    setState(() => _rows.add(row));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) row.key.focus.requestFocus();
    });
  }

  void _remove(_Row row) {
    setState(() => _rows.remove(row));
    // The row's boxes are still in this frame's tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
    commit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A row's own error is shown on its name box; the group line is for the
    // rest (such as too many entries).
    final rowErrors = [
      for (var i = 0; i < _rows.length; i++)
        commitTouched ? _keyError(i) : null,
    ];
    final groupError = rowErrors.any((e) => e != null) ? null : commitError;
    return PluginConfigGroup(
      field: widget.field,
      errorText: groupError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _rows.length; i++)
            Padding(
              key: ObjectKey(_rows[i]),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _box(
                      _rows[i].key,
                      l10n.pluginConfigMapKeyLabel,
                      rowErrors[i],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _box(_rows[i].value, l10n.pluginConfigMapValueLabel),
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

  Widget _box(PluginConfigRowBox box, String label, [String? error]) =>
      TextField(
        controller: box.controller,
        focusNode: box.focus,
        onChanged: (_) => commitChanged(),
        onSubmitted: (_) => commit(),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: error,
          errorMaxLines: 3,
        ),
      );
}
