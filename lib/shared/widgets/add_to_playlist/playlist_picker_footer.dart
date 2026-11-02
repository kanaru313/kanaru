import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// Title of the picker with the label and song count under it. The count
/// shows once the paths are read.
class PlaylistPickerHeader extends StatelessWidget {
  const PlaylistPickerHeader({
    super.key,
    required this.label,
    required this.songCount,
  });

  final String label;
  final int? songCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final songs = songCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.playlistPickerTitle),
        Text(
          songs == null
              ? label
              : l10n.playlistPickerSubtitle(
                  label,
                  l10n.playlistTrackCount(songs),
                ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// "N selected" (hidden at 0), Cancel and Add. Add is disabled at 0 and
/// while it runs ([busy]); Cancel is disabled while it runs.
class PlaylistPickerFooter extends StatelessWidget {
  const PlaylistPickerFooter({
    super.key,
    required this.selected,
    required this.busy,
    required this.onAdd,
  });

  final int selected;
  final bool busy;
  final VoidCallback onAdd;

  /// Key of the footer Row, for layout tests.
  static const rowKey = ValueKey('playlistPickerFooterRow');

  /// Widest the Add button grows. It stays a non-flex child so it sits flush
  /// right; the cap lets a long label ellipsize instead of overflowing.
  static const addMaxWidth = 180.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Row(
      key: rowKey,
      children: [
        Expanded(
          child: Text(
            selected == 0 ? '' : l10n.playlistPickerSelected(selected),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: addMaxWidth),
          child: FilledButton(
            onPressed: selected == 0 || busy ? null : onAdd,
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    selected > 1
                        ? l10n.playlistPickerAddMany(selected)
                        : l10n.playlistPickerAdd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ),
      ],
    );
  }
}
