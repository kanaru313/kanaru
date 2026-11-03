import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/genre_queries.dart';
import '../../core/database/library_database.dart' show LibraryDatabase;
import '../../core/player/track.dart';
import '../../l10n/l10n.dart';
import '../enqueue_tracks.dart';
import '../genre_display_name.dart';
import '../genre_summaries.dart';
import '../play_tracks.dart';
import '../widgets/queue_actions_menu.dart';

/// The songs of the genre's page, in its order.
Future<List<Track>> Function(LibraryDatabase db, String? covers) _genreTracks(
  GenreSummary genre,
) => (db, covers) async {
  final rows = await db.genreTracks(
    genre.raws,
    includeNull: genre.withoutGenre,
  );
  return [
    for (final t in rows)
      trackFromRow(t, covers),
  ];
};

/// [enqueueTracks] for a genre: its songs, in the order of its page.
void enqueueGenre(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  GenreSummary genre,
) => enqueueFromDatabase(
  ref,
  context,
  action,
  genreDisplayName(context.l10n, genre.key, genre.name),
  _genreTracks(genre),
);

/// Replaces the queue with the songs of the genre's page, in its order, and
/// plays from the first; see [playFromDatabase].
Future<void> playGenre(WidgetRef ref, GenreSummary genre) =>
    playFromDatabase(ref, 'Playing a genre failed', _genreTracks(genre));

/// [playGenre] (or its shuffled form) for a caller with no live
/// [WidgetRef], such as a modal action that runs after the row is gone.
Future<void> playGenreIn(
  ProviderContainer container,
  GenreSummary genre, {
  bool shuffle = false,
}) => playFromDatabaseIn(
  container,
  'Playing a genre failed',
  _genreTracks(genre),
  shuffle: shuffle,
);
