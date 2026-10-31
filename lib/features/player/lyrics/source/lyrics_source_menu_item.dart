import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics/lyrics.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/menu_row.dart';

/// "`.lrc` file" or "In the tag", from where the song's own lyrics come from.
String? lyricsSourceLocalSubtitle(AppLocalizations l10n, LyricsSource? own) =>
    switch (own) {
      LyricsSource.sidecar => l10n.lyricsSourceFile,
      LyricsSource.embedded => l10n.lyricsSourceLocalTag,
      null => null,
    };

/// One row: a title, an optional [tag] after it and an optional subtitle. With [checked] set it is a
/// radio row, selected when `true` (the choice in effect); pressing the row
/// that is already selected still acts, as the choice may carry a stored
/// version to drop. Without it, a plain action row.
Widget lyricsSourceMenuItem(
  BuildContext context, {
  required String title,
  required VoidCallback? onPressed,
  String? subtitle,
  Widget? subtitleWidget,
  String? tooltip,
  String? tag,
  IconData? icon,
  bool? checked,
  FocusNode? focusNode,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final label = ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tag == null)
          Text(title)
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    tag,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (subtitleWidget != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: DefaultTextStyle(
              style:
                  theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ) ??
                  const TextStyle(),
              child: subtitleWidget,
            ),
          )
        else if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    ),
  );
  final tip = tooltip;
  final shown = tip == null ? label : Tooltip(message: tip, child: label);
  if (checked == null) {
    return menuRowSpaced(
      MenuItemButton(
        focusNode: focusNode,
        style: menuRowStyle(),
        leadingIcon: icon == null ? null : Icon(icon, size: 20),
        onPressed: onPressed,
        child: shown,
      ),
    );
  }
  return menuRowSpaced(
    RadioMenuButton<bool>(
      focusNode: focusNode,
      // The row in effect is tinted, so it reads at a glance.
      style: menuRowStyle(
        background: checked ? menuRowSelectedTint(scheme) : null,
      ),
      value: true,
      groupValue: checked ? true : null,
      toggleable: true,
      onChanged: onPressed == null ? null : (_) => onPressed(),
      child: shown,
    ),
  );
}

/// The last row: a switch that says whether the song shows lyrics at all.
/// [on] is `true` unless the choice is "off".
Widget lyricsSourceSwitchItem(
  BuildContext context, {
  required String title,
  required bool on,
  required ValueChanged<bool>? onChanged,
}) => menuRowSpaced(
  MenuItemButton(
    style: menuRowStyle(),
    onPressed: onChanged == null ? null : () => onChanged(!on),
    trailingIcon: IgnorePointer(
      child: ExcludeFocus(
        child: Switch(value: on, onChanged: onChanged == null ? null : (_) {}),
      ),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: Text(title),
    ),
  ),
);

/// The subtitle of the "Online version" row: the source name (cut with an
/// ellipsis when long), "removed plugin" when its plugin is gone (dim), and
/// the kind and length, which are never cut.
Widget lyricsSourcePickSubtitle(
  BuildContext context, {
  required String name,
  required String? removedNote,
  required String? detail,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      if (removedNote != null)
        Text(
          ' · $removedNote',
          maxLines: 1,
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: scheme.error.withValues(alpha: 0.8),
          ),
        ),
      if (detail != null) Text(' · $detail', maxLines: 1),
    ],
  );
}
