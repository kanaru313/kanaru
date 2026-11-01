import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart';
import '../../../core/database/playlist_add_writes.dart';
import '../../../core/database/playlist_rows.dart';
import 'playlist_picker_dialog.dart';

/// What the picker decided: add [paths] to every playlist of [targets] (with
/// its mode) and create [newNames], in one write. Or, when reading the paths
/// failed, [error] and [stack] (rethrown by [showPlaylistPicker]).
class PlaylistAddPlan {
  const PlaylistAddPlan({
    required this.paths,
    this.targets = const {},
    this.newNames = const [],
  }) : error = null,
       stack = null;

  /// The ticked playlists: those holding some of [paths] (per [overlaps])
  /// get the missing songs only, the others all of them.
  PlaylistAddPlan.chosen({
    required this.paths,
    required List<PlaylistSummary> ticked,
    required Map<int, int> overlaps,
    required this.newNames,
  }) : targets = {
         for (final p in ticked)
           p: (overlaps[p.id] ?? 0) > 0
               ? PlaylistAddMode.missingOnly
               : PlaylistAddMode.appendAll,
       },
       error = null,
       stack = null;

  const PlaylistAddPlan.failed(this.error, this.stack)
    : paths = const [],
      targets = const {},
      newNames = const [];

  final List<String> paths;
  final Map<PlaylistSummary, PlaylistAddMode> targets;

  /// Trimmed names of the playlists to create, in the order they were typed.
  final List<String> newNames;

  final Object? error;
  final StackTrace? stack;
}

/// The multi-select playlist picker over [context]'s navigator. [paths]
/// starts being read by the caller; the picker shows how many of them each
/// playlist already holds. Completes with the plan once Add is pressed and
/// the paths are read, or null when dismissed or when there is nothing to
/// add. Throws what [paths] threw. Nothing is written or created here.
Future<PlaylistAddPlan?> showPlaylistPicker(
  BuildContext context, {
  required LibraryDatabase db,
  required Future<List<String>> paths,
  required String label,
  int? excludePlaylistId,
}) async {
  final plan = await showDialog<PlaylistAddPlan>(
    context: context,
    builder: (_) => PlaylistPickerDialog(
      db: db,
      paths: paths,
      label: label,
      excludePlaylistId: excludePlaylistId,
    ),
  );
  if (plan == null) return null;
  final error = plan.error;
  if (error != null) {
    Error.throwWithStackTrace(error, plan.stack ?? StackTrace.current);
  }
  return plan;
}
