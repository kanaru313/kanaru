import 'package:material_ui/material_ui.dart';

import '../../../core/database/playlist_modal_queries.dart';
import '../../../core/database/playlist_rows.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/context_modal/context_modal_header.dart';
import '../../../shared/widgets/library_row.dart';
import '../../../shared/widgets/playlist_cover.dart';

const double _coverSize = 64;

/// Top of the saved-queue modal: the collage, the time the queue was saved
/// and "N songs • length • K missing" (length and missing only when above
/// zero; [stats] is null until read).
///
/// With [onTap] (Go to queue, which closes the modal first) the whole header
/// is one button that does not take keyboard focus: the first row does. It is
/// null on the page of the queue itself.
class SavedQueueModalHeader extends StatelessWidget {
  const SavedQueueModalHeader({
    super.key,
    required this.playlist,
    required this.coverKeys,
    this.stats,
    this.onTap,
  });

  /// The queue under its shown name.
  final PlaylistSummary playlist;
  final List<String> coverKeys;
  final PlaylistModalStats? stats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final length = stats?.durationMs ?? 0;
    final missing = stats?.missing ?? 0;
    final meta = joinRowDetails([
      l10n.albumsSongCount(playlist.entryCount),
      if (length > 0) rowLength(l10n, length),
      if (missing > 0) l10n.queueModalMissingCount(missing),
    ]);
    return ContextModalHeader(
      leading: PlaylistCover(
        coverKeys: coverKeys,
        size: _coverSize,
        seed: 'queue:${playlist.id}',
      ),
      lines: [
        contextModalHeaderLine(playlist.name, theme.textTheme.titleMedium),
        contextModalHeaderLine(meta, quiet),
      ],
      onTap: onTap,
      tapHint: l10n.queueModalGoTo,
    );
  }
}
