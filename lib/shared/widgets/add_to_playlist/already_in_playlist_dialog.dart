import 'package:material_ui/material_ui.dart';

import '../../../core/database/playlist_add_writes.dart';
import '../../../l10n/l10n.dart';
import '../../icons/app_icons.dart';
import '../scroll_ink_surface.dart';

/// A target playlist that already holds [held] of the songs being added.
typedef AffectedPlaylist = ({String name, int held});

/// Asks what to do with songs the [affected] playlists already hold. The
/// dialog opens above [pickerContext]'s route, so the picker stays visible
/// and keeps its selection. [songCount] is the number of distinct songs
/// being added, the same unit as each `held`.
///
/// Completes with the chosen mode, or null when cancelled or dismissed.
Future<PlaylistAddMode?> showAlreadyInPlaylistDialog(
  BuildContext pickerContext, {
  required List<AffectedPlaylist> affected,
  required int songCount,
}) => showDialog<PlaylistAddMode>(
  context: pickerContext,
  builder: (_) =>
      _AlreadyInPlaylistDialog(affected: affected, songCount: songCount),
);

class _AlreadyInPlaylistDialog extends StatefulWidget {
  const _AlreadyInPlaylistDialog({
    required this.affected,
    required this.songCount,
  });

  final List<AffectedPlaylist> affected;
  final int songCount;

  @override
  State<_AlreadyInPlaylistDialog> createState() =>
      _AlreadyInPlaylistDialogState();
}

class _AlreadyInPlaylistDialogState extends State<_AlreadyInPlaylistDialog> {
  PlaylistAddMode? _mode;

  String _buildDescription(AppLocalizations l10n, int n) {
    final affected = widget.affected;

    if (affected.length > 1) {
      return l10n.alreadyInPlaylistMany(n, affected.length);
    }

    final first = affected.first;

    return first.held >= n
        ? l10n.alreadyInPlaylistOneAll(n, first.name)
        : l10n.alreadyInPlaylistOneSome(first.held, n, first.name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final many = widget.affected.length > 1;
    final n = widget.songCount;
    // Songs held more than once count once per playlist, as in the rows.
    final held = widget.affected.fold<int>(0, (sum, a) => sum + a.held);
    final nothingNew = widget.affected.every((a) => a.held >= n);
    final description = _buildDescription(l10n, n);
    return AlertDialog(
      title: Text(l10n.alreadyInPlaylistTitle),
      content: SizedBox(
        width: 420,
        // Rows scrolled under the title keep their ink in the content.
        child: ScrollInkSurface(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description),
                if (many) ...[
                  const SizedBox(height: 12),
                  _AffectedList(affected: widget.affected, songCount: n),
                ],
                const SizedBox(height: 8),
                RadioGroup<PlaylistAddMode>(
                  groupValue: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                  child: Column(
                    children: [
                      _option(
                        PlaylistAddMode.replaceOld,
                        AppIcons.moveDown,
                        l10n.alreadyInPlaylistReplace,
                        l10n.alreadyInPlaylistReplaceHint,
                      ),
                      _option(
                        PlaylistAddMode.missingOnly,
                        AppIcons.playlistAddCheck,
                        l10n.alreadyInPlaylistMissing,
                        nothingNew
                            ? (many
                                  ? l10n.alreadyInPlaylistMissingNothingMany
                                  : l10n.alreadyInPlaylistMissingNothingOne)
                            : l10n.alreadyInPlaylistMissingHint(held),
                      ),
                      _option(
                        PlaylistAddMode.appendAll,
                        AppIcons.addToPlaylist,
                        l10n.alreadyInPlaylistAll,
                        l10n.alreadyInPlaylistAllHint(held),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _mode == null
              ? null
              : () => Navigator.of(context).pop(_mode),
          child: Text(l10n.alreadyInPlaylistConfirm),
        ),
      ],
    );
  }

  Widget _option(
    PlaylistAddMode mode,
    IconData icon,
    String title,
    String hint,
  ) => RadioListTile<PlaylistAddMode>(
    value: mode,
    controlAffinity: ListTileControlAffinity.trailing,
    secondary: Icon(icon),
    title: Text(title),
    subtitle: Text(hint),
  );
}

/// Each affected playlist with how many of the songs it holds.
class _AffectedList extends StatelessWidget {
  const _AffectedList({required this.affected, required this.songCount});

  final List<AffectedPlaylist> affected;
  final int songCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: affected.length,
        separatorBuilder: (_, _) => Divider(
          height: 16,
          thickness: 0.5,
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        itemBuilder: (context, index) {
          final a = affected[index];
          final countText = a.held >= songCount
              ? l10n.alreadyInPlaylistRowAll(a.held)
              : l10n.alreadyInPlaylistRow(a.held, songCount);
          return Row(
            children: [
              Icon(
                AppIcons.playlistOutlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  a.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                countText,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}
