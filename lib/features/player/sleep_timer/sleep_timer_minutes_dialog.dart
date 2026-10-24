import 'package:material_ui/material_ui.dart';

import '../../../core/player/sleep_timer.dart';
import '../../../l10n/l10n.dart';

/// Asks for a number of minutes (a whole number from 1 to 720). Returns it,
/// or null when the dialog was dismissed.
Future<int?> showSleepTimerMinutesDialog(BuildContext context) =>
    showDialog<int>(
      context: context,
      builder: (context) => const _SleepTimerMinutesDialog(),
    );

class _SleepTimerMinutesDialog extends StatefulWidget {
  const _SleepTimerMinutesDialog();

  @override
  State<_SleepTimerMinutesDialog> createState() =>
      _SleepTimerMinutesDialogState();
}

class _SleepTimerMinutesDialogState extends State<_SleepTimerMinutesDialog> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  static int? _parse(String? text) {
    final minutes = int.tryParse(text?.trim() ?? '');
    if (minutes == null ||
        minutes < sleepTimerMinMinutes ||
        minutes > sleepTimerMaxMinutes) {
      return null;
    }
    return minutes;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(_parse(_text.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.sleepTimerCustomTitle),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _text,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.sleepTimerCustomLabel),
          validator: (value) => _parse(value) == null
              ? l10n.sleepTimerCustomInvalid(
                  sleepTimerMinMinutes,
                  sleepTimerMaxMinutes,
                )
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.sleepTimerStart)),
      ],
    );
  }
}
