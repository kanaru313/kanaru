import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/library_scan_prefs.dart';
import '../../l10n/l10n.dart';
import 'separator_entry_check.dart';
import 'separator_list_pages.dart';

/// One tab of the separator dialog: a field with an Add button over the
/// [entries] as a paged list. The tab only edits what it is given: every
/// accepted entry goes to [onAdd] and every removal to [onRemove]; the
/// owner stores them and passes the new list back.
class SeparatorEntryTab extends StatefulWidget {
  const SeparatorEntryTab({
    super.key,
    required this.entries,
    required this.fieldLabel,
    required this.helpText,
    required this.emptyText,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> entries;
  final String fieldLabel;
  final String helpText;
  final String emptyText;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<SeparatorEntryTab> createState() => _SeparatorEntryTabState();
}

class _SeparatorEntryTabState extends State<SeparatorEntryTab> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  SeparatorEntryProblem? _problem;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final check = checkSeparatorEntry(_text.text, widget.entries);
    final entry = check.entry;
    if (entry == null) {
      setState(() => _problem = check.problem);
    } else {
      widget.onAdd(entry);
      _text.clear();
      setState(() => _problem = null);
    }
    // The Add button took the focus; typing the next entry goes on at once.
    _focus.requestFocus();
  }

  String? _problemText(AppLocalizations l10n) => switch (_problem) {
    null => null,
    SeparatorEntryProblem.empty => l10n.separatorsErrorEmpty,
    SeparatorEntryProblem.full => l10n.separatorsErrorFull(maxSplitEntries),
    SeparatorEntryProblem.tooLong => l10n.separatorsErrorTooLong(
      maxSplitEntryLength,
    ),
    SeparatorEntryProblem.duplicate => l10n.separatorsErrorDuplicate,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                focusNode: _focus,
                // A control character would be dropped when the settings
                // load, so it never gets in.
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\x00-\x1f\x7f]')),
                ],
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_problem != null) setState(() => _problem = null);
                },
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: widget.fieldLabel,
                  helperText: widget.helpText,
                  helperMaxLines: 3,
                  errorText: _problemText(l10n),
                  errorMaxLines: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // As tall as the field, whatever the text under it.
            SizedBox(
              height: 56,
              child: FilledButton.tonal(
                onPressed: _submit,
                child: Text(l10n.separatorsAdd),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SeparatorListPages(
          entries: widget.entries,
          emptyText: widget.emptyText,
          onRemove: widget.onRemove,
        ),
      ],
    );
  }
}
