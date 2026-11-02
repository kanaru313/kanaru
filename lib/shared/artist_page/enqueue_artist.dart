import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart'
    show BrowseTrack, LibraryDatabase;
import '../../core/player/track.dart';
import '../enqueue_tracks.dart';
import '../play_tracks.dart';
import '../widgets/queue_actions_menu.dart';
import 'read_artist_sections.dart';

/// The songs of the artist's page, in its order.
Future<List<Track>> Function(LibraryDatabase db, String? covers) _artistTracks(
  String artistKey,
) => (db, covers) async {
  final sections = await readArtistSections(db, artistKey);
  return [
    for (final t in sections?.songs ?? const <BrowseTrack>[])
      trackFromRow(t, covers),
  ];
};

/// [enqueueTracks] for an artist: the songs of their page, in its order.
void enqueueArtist(
  WidgetRef ref,
  BuildContext context,
  QueueAction action,
  String artistKey,
  String name,
) => enqueueFromDatabase(ref, context, action, name, _artistTracks(artistKey));

/// Replaces the queue with the songs of the artist's page, in its order, and
/// plays from the first; see [playFromDatabase].
Future<void> playArtist(WidgetRef ref, String artistKey) =>
    playFromDatabase(ref, 'Playing an artist failed', _artistTracks(artistKey));

/// [playArtist] (or its shuffled form) for a caller with no live
/// [WidgetRef], such as a modal action that runs after the row is gone.
Future<void> playArtistIn(
  ProviderContainer container,
  String artistKey, {
  bool shuffle = false,
}) => playFromDatabaseIn(
  container,
  'Playing an artist failed',
  _artistTracks(artistKey),
  shuffle: shuffle,
);
