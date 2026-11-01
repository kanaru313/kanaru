import 'package:flutter/widgets.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/playlist_add_queries.dart';
import '../../../core/database/playlist_add_writes.dart';
import '../../../core/database/playlist_rows.dart';
import 'add_to_playlist_dialog.dart';
import 'already_in_playlist_dialog.dart';

/// The picker's Add step after the [paths] are read: looks at what the ticked
/// playlists already hold and, when they hold some of the songs, asks once
/// what to do with them. The choice applies to those playlists only; the
/// other ticked ones and the new ones get every song.
///
/// The question opens above [pickerContext]. [liveTicked] and [newNames]
/// are read again after each wait, so playlists deleted meanwhile are
/// dropped. Returns null when the picker should stay open: [isCurrent]
/// turned false, the question was cancelled, or nothing is left to add to.
Future<PlaylistAddPlan?> planPickerAdd({
  required LibraryDatabase db,
  required List<String> paths,
  required List<PlaylistSummary> Function() liveTicked,
  required List<String> Function() newNames,
  required bool Function() isCurrent,
  required BuildContext Function() pickerContext,
}) async {
  final overlaps = await db.playlistOverlapCounts(
    paths,
    playlistIds: [for (final p in liveTicked()) p.id],
  );
  if (!isCurrent()) return null;
  final live = liveTicked();
  final affected = [
    for (final p in live)
      if ((overlaps[p.id] ?? 0) > 0) (name: p.name, held: overlaps[p.id]!),
  ];
  final affectedIds = {
    for (final p in live)
      if ((overlaps[p.id] ?? 0) > 0) p.id,
  };
  var mode = PlaylistAddMode.appendAll;
  if (affected.isNotEmpty) {
    // Distinct songs: the unit of the held counts.
    final chosen = await showAlreadyInPlaylistDialog(
      pickerContext(),
      affected: affected,
      songCount: paths.toSet().length,
    );
    if (chosen == null || !isCurrent()) return null;
    mode = chosen;
  }
  final targets = liveTicked();
  final names = newNames();
  if (targets.isEmpty && names.isEmpty) return null;
  return PlaylistAddPlan.chosen(
    paths: paths,
    ticked: targets,
    affected: affectedIds,
    mode: mode,
    newNames: names,
  );
}
