import 'package:material_ui/material_ui.dart';

/// Asks before an action: Cancel and a confirm button. With [destructive]
/// (the default) the confirm button is in the error colours, for actions that
/// cannot be undone. Completes with `true` only when the user confirms;
/// Cancel, Esc and a tap outside all answer `false`.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final colors = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
