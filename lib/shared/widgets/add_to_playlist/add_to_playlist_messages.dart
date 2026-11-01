import '../../../core/database/playlist_add_writes.dart';
import '../../../l10n/app_localizations.dart';
import '../app_snack_bar.dart';
import 'add_to_playlist_dialog.dart';

/// How to tell the result of adding: nothing new is only a note.
AppSnackBarKind playlistAddedKind(int added) =>
    added == 0 ? AppSnackBarKind.info : AppSnackBarKind.success;

/// The text for [added] songs put in and [skipped] already there in the
/// playlist named [playlistName]; [label] names what was added.
String playlistAddedText(
  AppLocalizations l10n,
  String label,
  String playlistName,
  int added,
  int skipped,
) => added == 0
    ? l10n.playlistAlreadyIn(label, playlistName)
    : skipped == 0
    ? l10n.playlistAdded(label, playlistName)
    : l10n.playlistAddedSkipped(added, skipped, playlistName);

/// The one snackbar for [outcome] of writing [plan]; [label] names what was
/// added. A single target keeps the per-playlist wording, several get totals.
/// [existingIds] are the playlists that still existed after the write; targets
/// outside it were gone and are not named. Null means all of them existed.
(AppSnackBarKind, String) playlistAddMessage(
  AppLocalizations l10n,
  PlaylistAddOutcome outcome,
  PlaylistAddPlan plan,
  String label, {
  Set<int>? existingIds,
}) {
  // Every target was gone and nothing was created.
  if (outcome.targetCount == 0) {
    return (AppSnackBarKind.error, l10n.playlistSaveFailed);
  }
  final names = [
    for (final t in plan.targets.keys)
      if (existingIds == null || existingIds.contains(t.id)) t.name,
    ...plan.newNames,
  ];
  if (names.length == 1) {
    final added = outcome.added;
    return (
      playlistAddedKind(added),
      playlistAddedText(l10n, label, names.first, added, outcome.skipped),
    );
  }
  if (outcome.added == 0) {
    return (
      AppSnackBarKind.info,
      l10n.playlistAlreadyInMany(outcome.targetCount, names.join(', ')),
    );
  }
  final created = outcome.created.length;
  final text =
      l10n.playlistAddedToMany(plan.paths.length, outcome.targetCount) +
      (created > 0 ? l10n.playlistAddedNewSuffix(created) : '') +
      (outcome.skipped > 0
          ? l10n.playlistAddedSkippedSuffix(outcome.skipped)
          : '');
  return (AppSnackBarKind.success, text);
}
