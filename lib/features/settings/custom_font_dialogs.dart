import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

Future<bool> confirmCustomFontDisclaimer(BuildContext context) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.customFontDisclaimerTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Text(l10n.customFontDisclaimerBody),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.fontDialogCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.customFontDisclaimerConfirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Custom fonts cannot be re-downloaded, so deleting asks first.
Future<bool> confirmDeleteCustomFont(BuildContext context, String fontName) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteCustomFontTitle),
      content: Text(l10n.deleteCustomFontBody(fontName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.fontDialogCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.deleteCustomFontConfirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
