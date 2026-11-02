import 'package:material_ui/material_ui.dart';

import '../../core/database/playlist_rows.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'playlist_edit_cover.dart';
import 'playlist_edit_fields.dart';

/// What the edit dialog returns on Save: both values trimmed.
typedef PlaylistDetailsEdit = ({String name, String description});

/// Dialog width at which the cover sits beside the fields instead of above.
const _twoColumnWidth = 520.0;

/// Opens the edit dialog for [playlist]. [context] must belong to the root
/// navigator so the dialog stands above any menu that opened it. Completes
/// with the trimmed values on Save, or null on Close, Cancel, Esc or a tap
/// outside.
Future<PlaylistDetailsEdit?> showPlaylistEditDialog(
  BuildContext context, {
  required PlaylistSummary playlist,
  required List<String> coverKeys,
}) => showDialog<PlaylistDetailsEdit>(
  context: context,
  builder: (context) =>
      _PlaylistEditDialog(playlist: playlist, coverKeys: coverKeys),
);

class _PlaylistEditDialog extends StatefulWidget {
  const _PlaylistEditDialog({required this.playlist, required this.coverKeys});

  final PlaylistSummary playlist;
  final List<String> coverKeys;

  @override
  State<_PlaylistEditDialog> createState() => _PlaylistEditDialogState();
}

class _PlaylistEditDialogState extends State<_PlaylistEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;

  /// Keeps the fields (and their focus) alive when the layout switches
  /// between one and two columns.
  final _fieldsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final initial = widget.playlist.name;
    // Fully selected, so typing replaces the name.
    _name = TextEditingController(text: initial)
      ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
    _description = TextEditingController(text: widget.playlist.description);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Pops the trimmed values; does nothing while the name is blank (Enter
  /// reaches here even when Save is disabled).
  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context)
        .pop((name: name, description: _description.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fields = PlaylistEditFields(
      key: _fieldsKey,
      name: _name,
      description: _description,
      onSubmit: _save,
    );
    final cover = PlaylistEditCover(
      playlist: widget.playlist,
      coverKeys: widget.coverKeys,
    );
    return Dialog(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 10, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.playlistEditTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.playlistEditClose,
                  icon: const Icon(AppIcons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth >= _twoColumnWidth
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          cover,
                          const SizedBox(width: 20),
                          Expanded(child: fields),
                        ],
                      )
                    : Column(
                        children: [cover, const SizedBox(height: 20), fields],
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: _name,
                  builder: (context, value, _) => FilledButton(
                    onPressed: value.text.trim().isEmpty ? null : _save,
                    child: Text(l10n.playlistEditSave),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
