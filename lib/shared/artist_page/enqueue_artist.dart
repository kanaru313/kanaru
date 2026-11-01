import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show BrowseTrack;
import '../../core/indexer/cover_paths.dart';
import '../enqueue_tracks.dart';
import '../play_tracks.dart';
import '../widgets/queue_actions_menu.dart';
import 'read_artist_sections.dart';

/// [enqueueTracks] for an artist: the songs of their page, in its order.
void enqueueArtist(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  String artistKey,
  String name,
) => enqueueFromDatabase(ref, context, action, name, (db, covers) async {
  final sections = await readArtistSections(db, artistKey);
  return [
    for (final t in sections?.songs ?? const <BrowseTrack>[])
      trackFromBrowse(t, artPath: coverPath(covers, t.coverKey)),
  ];
});

/// Replaces the queue with the songs of the artist's page, in its order, and
/// plays from the first; see [playFromDatabase].
Future<void> playArtist(WidgetRef ref, String artistKey) =>
    playFromDatabase(ref, 'Playing an artist failed', (db, covers) async {
      final sections = await readArtistSections(db, artistKey);
      return [
        for (final t in sections?.songs ?? const <BrowseTrack>[])
          trackFromBrowse(t, artPath: coverPath(covers, t.coverKey)),
      ];
    });
