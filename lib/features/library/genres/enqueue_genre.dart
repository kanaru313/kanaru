import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/genre_queries.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../shared/enqueue_tracks.dart';
import '../../../shared/genre_summaries.dart';
import '../../../shared/play_tracks.dart';
import '../../../shared/widgets/queue_actions_menu.dart';

/// [enqueueTracks] for a genre: its songs, in the order of its page.
void enqueueGenre(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  GenreSummary genre,
) => enqueueFromDatabase(ref, context, action, genre.name, (db, covers) async {
  return [
    for (final t in await db.genreTracks(genre.raws))
      trackFromBrowse(t, artPath: coverPath(covers, t.coverKey)),
  ];
});
