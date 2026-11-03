import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/song_modal/song_modal_extras.dart';
import '../../shared/widgets/context_modal/context_modal_header.dart';
import '../../shared/widgets/context_modal/context_modal_route.dart';

const double _tileSize = 64;

/// Opens the modal of a play or a Most played row whose file is not in the
/// library: a crossed-note tile, the file name of [path], "Not in library"
/// and the [chip] (the row's own text; none when null). Its rows are the [extras] actions
/// (Song history, Remove from history) and it has no footer, since nothing
/// here can be queued. [viaKeyboard] focuses the first row.
void openHistoryMissingPlayModal(
  BuildContext context, {
  required String path,
  String? chip,
  required SongModalExtras extras,
  bool viaKeyboard = false,
}) {
  final l10n = context.l10n;
  unawaited(
    showContextModal<void>(
      context,
      root: ContextModalPage(
        key: 'history-missing-play',
        headerBuilder: (context, nav) =>
            _MissingPlayHeader(path: path, chip: chip),
        bodyBuilder: (context, nav) => [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(nav, [extras.actions]),
          ),
        ],
      ),
      semanticLabel: l10n.historyMissingPlayModalLabel,
      viaKeyboard: viaKeyboard,
    ),
  );
}

class _MissingPlayHeader extends StatelessWidget {
  const _MissingPlayHeader({required this.path, required this.chip});

  final String path;
  final String? chip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ContextModalHeader(
      leading: SizedBox.square(
        dimension: _tileSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            AppIcons.musicOff,
            size: 32,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
      lines: [
        contextModalHeaderLine(
          path.split('/').last,
          theme.textTheme.titleMedium,
        ),
        contextModalHeaderLine(
          context.l10n.playlistNotInLibrary,
          theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        if (chip case final chip?) ContextModalHeaderChip(chip),
      ],
    );
  }
}
