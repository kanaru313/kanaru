import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics/lyrics.dart';
import '../../../../l10n/l10n.dart';

/// "`.lrc` file" or "In the tag", from where the song's own lyrics come from.
String? lyricsSourceLocalSubtitle(AppLocalizations l10n, LyricsSource? own) =>
    switch (own) {
      LyricsSource.sidecar => l10n.lyricsSourceFile,
      LyricsSource.embedded => l10n.lyricsSourceLocalTag,
      null => null,
    };

/// One row: a title and an optional subtitle. With [checked] set it is a
/// radio row, selected when `true` (the choice in effect); pressing the row
/// that is already selected still acts, as the choice may carry a stored
/// version to drop. Without it, a plain action row.
Widget lyricsSourceMenuItem(
  BuildContext context, {
  required String title,
  required VoidCallback? onPressed,
  String? subtitle,
  bool? checked,
  FocusNode? focusNode,
}) {
  final theme = Theme.of(context);
  final label = ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        if (subtitle != null)
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    ),
  );
  if (checked == null) {
    return MenuItemButton(
      focusNode: focusNode,
      onPressed: onPressed,
      child: label,
    );
  }
  return RadioMenuButton<bool>(
    focusNode: focusNode,
    value: true,
    groupValue: checked ? true : null,
    toggleable: true,
    onChanged: onPressed == null ? null : (_) => onPressed(),
    child: label,
  );
}
