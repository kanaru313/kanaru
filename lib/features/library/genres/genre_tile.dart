import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/genre_summaries.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import 'genre_avatar.dart';

/// One genre row: round avatar, name, "N songs".
class GenreTile extends StatelessWidget {
  const GenreTile({
    super.key,
    required this.genre,
    required this.onTap,
    this.onQueueAction,
  });

  final GenreSummary genre;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: GenreAvatar(genreKey: genre.key, size: 40),
      title: Text(genre.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        context.l10n.albumsSongCount(genre.songCount),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
    return QueueActionsRegion(onAction: onQueueAction, child: tile);
  }
}
