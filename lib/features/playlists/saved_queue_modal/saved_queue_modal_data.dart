import 'package:flutter/widgets.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/playlist_modal_queries.dart';
import '../../../core/database/playlist_rows.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../playlist_modal_stats_provider.dart';
import '../playlist_page_data.dart';
import '../queue_history_actions.dart';

/// What the saved-queue modal needs to know about the queue, to decide which
/// rows show and which are greyed out.
class SavedQueueModalData {
  const SavedQueueModalData({
    required this.snapshot,
    required this.snapshotCoverKeys,
    required this.l10n,
    this.load,
    this.stats,
    this.showGoTo = true,
  });

  /// The summary the modal was opened with; text only until [load] arrives.
  final PlaylistSummary snapshot;
  final List<String> snapshotCoverKeys;
  final AppLocalizations l10n;

  /// Null while the head loads.
  final PlaylistHeadLoad? load;

  /// Null until the length and the missing count were read.
  final PlaylistModalStats? stats;

  /// False on the page of the queue itself.
  final bool showGoTo;

  PlaylistPageHead? get head => load?.head;

  /// The queue does not exist any more (deleted elsewhere): the header keeps
  /// the snapshot and every acting row is greyed out.
  bool get gone => load != null && load!.head == null;

  /// The latest summary under its shown name (the time it was saved); the
  /// stored name is a placeholder that never shows.
  PlaylistSummary get playlist =>
      namedQueueSummary(head?.playlist ?? snapshot, l10n);

  List<String> get coverKeys => head?.coverKeys ?? snapshotCoverKeys;

  /// Whether a song in the library can be played; false until the head says so.
  bool get hasPlayable => head?.hasPlayable ?? false;

  /// Whether the queue has entries to export (missing files included).
  bool get hasEntries => !gone && playlist.entryCount > 0;

  /// Entries whose file is not in the library; 0 until read.
  int get missing => stats?.missing ?? 0;
}

/// Watches the head and the counts of the queue of [snapshot] and returns
/// what they say now. Both keep the previous value while they reload. The
/// Advanced page watches through this too, which keeps both providers alive
/// while the first page is unmounted.
SavedQueueModalData watchSavedQueueModalData(
  WidgetRef ref, {
  required PlaylistSummary snapshot,
  required List<String> snapshotCoverKeys,
  required bool showGoTo,
  required AppLocalizations l10n,
}) => SavedQueueModalData(
  snapshot: snapshot,
  snapshotCoverKeys: snapshotCoverKeys,
  l10n: l10n,
  load: ref.watch(playlistPageHeadProvider(snapshot.id)).value,
  stats: ref.watch(playlistModalStatsProvider(snapshot.id)).value,
  showGoTo: showGoTo,
);

/// What the actions do. Each one runs after the modal has closed, except
/// [openAdvanced], which pushes a page, and [delete] and [removeMissing],
/// which close the modal only once confirmed.
class SavedQueueModalHandlers {
  const SavedQueueModalHandlers({
    required this.goToQueue,
    required this.play,
    required this.shuffle,
    required this.addToPlaylist,
    required this.delete,
    required this.addAllToFavorites,
    required this.exportAbsolute,
    required this.exportRelative,
    required this.removeMissing,
    this.openAdvanced,
  });

  final VoidCallback goToQueue;
  final VoidCallback play;
  final VoidCallback shuffle;

  /// Copies every stored entry into playlists the user picks.
  final VoidCallback addToPlaylist;
  final void Function(ContextModalNav nav) delete;
  final VoidCallback addAllToFavorites;
  final VoidCallback exportAbsolute;
  final VoidCallback exportRelative;
  final void Function(ContextModalNav nav) removeMissing;
  final void Function(ContextModalNav nav)? openAdvanced;
}
