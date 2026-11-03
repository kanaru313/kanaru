import 'package:flutter/widgets.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/playlist_modal_queries.dart';
import '../../../core/database/playlist_rows.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/context_modal/context_modal_nav.dart';
import '../playlist_page_data.dart';
import '../queue_history_actions.dart';
import 'playlist_modal_stats_provider.dart';

/// What the actions page needs to know about the playlist, to decide which
/// rows show and which are greyed out.
class PlaylistModalData {
  const PlaylistModalData({
    required this.snapshot,
    required this.snapshotCoverKeys,
    this.load,
    this.stats,
    this.showGoTo = true,
    this.savedQueue = false,
    this.queueL10n,
  });

  /// The summary the modal was opened with; text only until [load] arrives.
  final PlaylistSummary snapshot;
  final List<String> snapshotCoverKeys;

  /// Null while the head loads.
  final PlaylistHeadLoad? load;

  /// Null until the missing and repeated counts were read.
  final PlaylistModalStats? stats;

  /// False on the page of the playlist itself.
  final bool showGoTo;

  /// The modal is of a saved queue: no Edit, no Duplicate, no repeats clean-up,
  /// and the name is the time it was saved.
  final bool savedQueue;

  /// Texts that name a saved queue; without them the stored name shows.
  final AppLocalizations? queueL10n;

  PlaylistPageHead? get head => load?.head;

  /// The playlist does not exist any more (deleted elsewhere): the header
  /// keeps the snapshot and every acting row is greyed out.
  bool get gone => load != null && load!.head == null;

  /// The latest summary: the loaded head's, else the snapshot. A saved queue
  /// is renamed here once, so labels, file names and messages never show the
  /// stored placeholder.
  PlaylistSummary get playlist {
    final latest = head?.playlist ?? snapshot;
    final l10n = queueL10n;
    return savedQueue && l10n != null
        ? namedQueueSummary(latest, l10n)
        : latest;
  }

  List<String> get coverKeys => head?.coverKeys ?? snapshotCoverKeys;
  bool get isFavorites => playlist.isFavorites;

  /// Whether a song in the library can be played; false until the head says so.
  bool get hasPlayable => head?.hasPlayable ?? false;

  /// Whether the playlist has entries to copy or export (missing files
  /// included).
  bool get hasEntries => !gone && playlist.entryCount > 0;
}

/// Watches the head and the counts of the playlist of [snapshot] and returns
/// what they say now. Both keep the previous value while they reload, so the
/// rows do not flicker grey on a playlist edit. The Advanced page watches
/// through this too, which keeps both providers alive while the first page
/// is unmounted.
PlaylistModalData watchPlaylistModalData(
  WidgetRef ref, {
  required PlaylistSummary snapshot,
  required List<String> snapshotCoverKeys,
  required bool showGoTo,
  bool savedQueue = false,
  AppLocalizations? queueL10n,
}) => PlaylistModalData(
  snapshot: snapshot,
  snapshotCoverKeys: snapshotCoverKeys,
  load: ref.watch(playlistPageHeadProvider(snapshot.id)).value,
  stats: ref.watch(playlistModalStatsProvider(snapshot.id)).value,
  showGoTo: showGoTo,
  savedQueue: savedQueue,
  queueL10n: queueL10n,
);

/// What the actions do. Each one runs after the modal has closed, except
/// [openAdvanced], which pushes a page, [edit], which opens a dialog above
/// the open modal, and [delete], which closes the modal only once confirmed.
class PlaylistModalHandlers {
  const PlaylistModalHandlers({
    required this.goToPlaylist,
    required this.play,
    required this.shuffle,
    required this.addToPlaylist,
    required this.edit,
    required this.delete,
    required this.addAllToFavorites,
    required this.duplicate,
    required this.exportAbsolute,
    required this.exportRelative,
    required this.removeDuplicates,
    required this.removeMissing,
    this.openAdvanced,
  });

  final VoidCallback goToPlaylist;
  final VoidCallback play;
  final VoidCallback shuffle;

  /// Copies every entry as stored into playlists the user picks.
  final VoidCallback addToPlaylist;
  final VoidCallback edit;
  final void Function(ContextModalNav nav) delete;
  final VoidCallback addAllToFavorites;
  final VoidCallback duplicate;
  final VoidCallback exportAbsolute;
  final VoidCallback exportRelative;
  final VoidCallback removeDuplicates;
  final void Function(ContextModalNav nav) removeMissing;
  final void Function(ContextModalNav nav)? openAdvanced;
}
