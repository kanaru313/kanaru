import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/confirm_dialog.dart';

/// "Gỡ (tên)?": says installed plugins stay but stop getting updates.
/// Completes with `true` only when the user confirms.
Future<bool> confirmRemoveRepository(BuildContext context, String name) {
  final l10n = context.l10n;
  return confirmAction(
    context,
    title: l10n.lyricsStoreRemoveRepoTitle(name),
    body: l10n.lyricsStoreRemoveRepoBody,
    confirmLabel: l10n.lyricsStoreRemoveRepoConfirm,
  );
}
