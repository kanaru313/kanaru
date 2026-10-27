import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/add_to_playlist/create_playlist_prompt.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/queue_actions_menu.dart';
import 'history_top_queue.dart';

/// What the vertical "more" button of the Most played page can do.
enum MostPlayedChoice { createPlaylist, playNext, addToQueue }

/// The "more" button next to Play and Shuffle: Create playlist, Play next and
/// Add to queue, all greyed out when [enabled] is false (no listed song is in
/// the library any more).
class MostPlayedMenuButton extends StatelessWidget {
  const MostPlayedMenuButton({
    super.key,
    required this.enabled,
    required this.onSelected,
  });

  final bool enabled;
  final ValueChanged<MostPlayedChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<MostPlayedChoice>(
      tooltip: l10n.historyMore,
      icon: const Icon(AppIcons.more),
      onSelected: onSelected,
      itemBuilder: (context) => [
        menuRow(
          MostPlayedChoice.createPlaylist,
          AppIcons.newPlaylist,
          l10n.historyCreatePlaylist,
          enabled: enabled,
        ),
        menuRow(
          MostPlayedChoice.playNext,
          AppIcons.playlistPlay,
          l10n.queuePlayNext,
          enabled: enabled,
        ),
        menuRow(
          MostPlayedChoice.addToQueue,
          AppIcons.addToQueue,
          l10n.queueAddToQueue,
          enabled: enabled,
        ),
      ],
    );
  }
}

/// Runs the page-level [choice] on the songs of [rows] that can play, in rank
/// order. [rangeText] names the playlist and the queue message.
void runMostPlayedChoice(
  WidgetRef ref,
  BuildContext context,
  MostPlayedChoice choice,
  List<HistoryTopRow> rows,
  String rangeText,
) {
  switch (choice) {
    case MostPlayedChoice.createPlaylist:
      unawaited(_createPlaylist(ref, context, rows, rangeText));
    case MostPlayedChoice.playNext:
      enqueueLoaded(
        ref,
        context,
        QueueAction.playNext,
        historyTopPlayable(rows, ref.read(coverCacheDirectoryProvider)),
        rangeText,
      );
    case MostPlayedChoice.addToQueue:
      enqueueLoaded(
        ref,
        context,
        QueueAction.addToQueue,
        historyTopPlayable(rows, ref.read(coverCacheDirectoryProvider)),
        rangeText,
      );
  }
}

/// Plays the songs of [rows] that can play, in rank order, from the first.
void playMostPlayed(WidgetRef ref, List<HistoryTopRow> rows) => playTracks(
  ref,
  historyTopPlayable(rows, ref.read(coverCacheDirectoryProvider)),
  0,
);

/// Shuffles the songs of [rows] that can play into the queue.
void shuffleMostPlayed(WidgetRef ref, List<HistoryTopRow> rows) =>
    shuffleTracks(
      ref,
      historyTopPlayable(rows, ref.read(coverCacheDirectoryProvider)),
    );

Future<void> _createPlaylist(
  WidgetRef ref,
  BuildContext context,
  List<HistoryTopRow> rows,
  String rangeText,
) async {
  final db = ref.read(libraryDatabaseProvider);
  if (db == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final created = await promptAndCreatePlaylist(
    context,
    db,
    messenger,
    l10n,
    paths: [for (final row in rows) ?row.track?.path],
    initialName: l10n.historyTopPlaylistName(rangeText),
  );
  if (created == null || !messenger.mounted) return;
  messenger.showSnackBar(
    appSnackBar(
      kind: AppSnackBarKind.success,
      title: l10n.historyPlaylistCreated(created.name),
    ),
  );
}
