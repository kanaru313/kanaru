import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/database/playlist_library_paths.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/playing_track_art.dart' show localPathOf;
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/add_to_playlist/create_playlist_prompt.dart';

final _log = Logger('playlists');

/// The paths of [tracks] to save as a playlist: in queue order, only local
/// files in [inLibrary], each once (first occurrence). [skipped] counts the
/// tracks left out (not in the library, or repeats).
({List<String> paths, int skipped}) queuePlaylistPaths(
  List<Track> tracks,
  Set<String> inLibrary,
) {
  final paths = <String>[];
  final seen = <String>{};
  for (final track in tracks) {
    final path = localPathOf(track.uri);
    if (path != null && inLibrary.contains(path) && seen.add(path)) {
      paths.add(path);
    }
  }
  return (paths: paths, skipped: tracks.length - paths.length);
}

/// Saves the queue as a new playlist: asks for a name (default: "Queue"
/// and the date), then stores the library songs of the queue in the order shown,
/// played ones included. The queue is read once, when this starts; changes
/// made while the name dialog is open are not saved.
///
/// Everything from the widget tree is captured before the first `await`.
/// Failures are logged and reported, never thrown.
Future<void> saveQueueAsPlaylist(WidgetRef ref, BuildContext context) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final tracks = ref.read(playerServiceProvider).queue.tracks;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  // The root navigator sits above the side sheet and Now Playing.
  final navigator = Navigator.of(context, rootNavigator: true);
  void say(String text) => messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(text)));

  final ({List<String> paths, int skipped}) picked;
  try {
    final candidates = [for (final track in tracks) ?localPathOf(track.uri)];
    picked = queuePlaylistPaths(tracks, await db.libraryPathsAmong(candidates));
  } catch (error, stack) {
    _log.severe(
      'Reading the queue songs from the library failed',
      error,
      stack,
    );
    say(l10n.playlistSaveFailed);
    return;
  }
  if (picked.paths.isEmpty) {
    say(l10n.queueSaveNothing);
    return;
  }
  if (!navigator.mounted) return;
  final created = await promptAndCreatePlaylist(
    navigator.context,
    db,
    messenger,
    l10n,
    paths: picked.paths,
    initialName: l10n.queueSaveDefaultName(DateTime.now()),
  );
  if (created == null) return;
  say(
    picked.skipped == 0
        ? l10n.queueSaved(picked.paths.length, created.name)
        : l10n.queueSavedSkipped(
            picked.paths.length,
            picked.skipped,
            created.name,
          ),
  );
}
