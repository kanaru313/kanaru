import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// "Gỡ (tên)?": says installed plugins stay but stop getting updates.
/// Completes with `true` only when the user confirms.
Future<bool> confirmRemoveRepository(BuildContext context, String name) async {
  final l10n = context.l10n;
  final colors = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.lyricsStoreRemoveRepoTitle(name)),
      content: Text(l10n.lyricsStoreRemoveRepoBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.lyricsStoreRemoveRepoConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
