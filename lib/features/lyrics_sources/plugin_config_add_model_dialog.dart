import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/store/plugin_config_values.dart';
import '../../l10n/l10n.dart';

/// A model the user typed: its name and an optional note.
typedef PluginConfigNewModel = ({String name, String? note});

/// Asks for the name (and a note) of a model to add to a `custom` select.
/// Null when cancelled. The name is required.
Future<PluginConfigNewModel?> showPluginConfigAddModelDialog(
  BuildContext context,
) => showDialog<PluginConfigNewModel>(
  context: context,
  builder: (_) => const _AddModelDialog(),
);

class _AddModelDialog extends StatefulWidget {
  const _AddModelDialog();

  @override
  State<_AddModelDialog> createState() => _AddModelDialogState();
}

class _AddModelDialogState extends State<_AddModelDialog> {
  final _name = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  void _submit() {
    if (!_valid) return;
    final note = _note.text.trim();
    Navigator.of(context)
        .pop((name: _name.text.trim(), note: note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.pluginConfigAddModelTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              inputFormatters: [_CodePointLimit(pluginCustomChoiceMaxValue)],
              decoration: InputDecoration(
                hintText: l10n.pluginConfigAddModelName,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              inputFormatters: [
                LengthLimitingTextInputFormatter(pluginCustomChoiceMaxSubtitle),
              ],
              decoration: InputDecoration(
                hintText: l10n.pluginConfigAddModelNote,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _valid ? _submit : null,
          child: Text(l10n.pluginConfigAddAndSelect),
        ),
      ],
    );
  }
}

/// Holds the text to [max] code points, the unit the store counts, cutting a
/// longer paste at the limit.
class _CodePointLimit extends TextInputFormatter {
  const _CodePointLimit(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= max) return newValue;
    final text = String.fromCharCodes(newValue.text.runes.take(max));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
