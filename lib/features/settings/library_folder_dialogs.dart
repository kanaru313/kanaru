import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'settings_confirm_dialog.dart';

/// Asks before a folder leaves the library. [songCount] songs go with it.
/// Completes with `true` only when the user confirms.
Future<bool> confirmRemoveFolder(
  BuildContext context, {
  required String path,
  required int songCount,
}) {
  final l10n = context.l10n;
  return confirmDestructive(
    context,
    title: l10n.settingsRemoveFolderTitle,
    body: '$path\n\n${l10n.settingsRemoveFolderBody(songCount)}',
    confirmLabel: l10n.settingsRemoveFolderConfirm,
  );
}

/// Asks before the folder at [oldPath] is swapped for [newPath].
Future<bool> confirmReplaceFolder(
  BuildContext context, {
  required String oldPath,
  required String newPath,
}) {
  final l10n = context.l10n;
  return confirmDestructive(
    context,
    title: l10n.settingsReplaceFolderTitle,
    body: l10n.settingsReplaceFolderBody(oldPath, newPath),
    confirmLabel: l10n.settingsReplaceFolderConfirm,
  );
}
