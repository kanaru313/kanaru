import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/enqueue_tracks.dart';
import '../../shared/play_tracks.dart';
import '../../shared/song_modal/open_song_modal.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/library_loading.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'history_missing_play_modal.dart';
import 'history_song_modal_extras.dart';
import 'history_providers.dart';
import 'history_screen_states.dart';
import 'history_track_header.dart';
import 'history_track_play_tile.dart';

/// The history page of one song, reached from the menu of a History row:
/// totals, then every play newest first. A play is removed through its row
/// modal, with Undo. The page stays when the last play goes.
///
/// [path] comes from the address and is only used to look the song up. The
/// player gets the path of the `tracks` row that matches it, so an address
/// typed by hand never reaches the player. Null or empty shows "not found".
class HistoryTrackScreen extends ConsumerStatefulWidget {
  const HistoryTrackScreen({super.key, required this.path});

  final String? path;

  @override
  ConsumerState<HistoryTrackScreen> createState() => _HistoryTrackScreenState();
}

class _HistoryTrackScreenState extends ConsumerState<HistoryTrackScreen> {
  void _play(HistoryTrackSummary summary) {
    final track = summary.track;
    if (track == null) return;
    playTracks(ref, [
      trackFromRow(track, ref.read(coverCacheDirectoryProvider)),
    ], 0);
  }

  /// Opens the modal of [row]: the song modal when the song is in the
  /// library, the Missing-play modal otherwise. The play is the one the modal
  /// was opened on: the list may move before a choice is made.
  void _openModal(
    HistoryTrackSummary summary,
    HistoryPlayRow row, {
    required bool viaKeyboard,
  }) {
    final chip = context.l10n.historyPlayedChip(
      historyTrackPlayWhen(context, row.playedAt),
    );
    final extras = historyPlayExtras(
      context: context,
      ref: ref,
      path: row.path,
      location: null,
      playId: row.id,
      headerNote: chip,
    );
    final item = summary.track;
    if (item == null) {
      openHistoryMissingPlayModal(
        context,
        path: row.path,
        chip: chip,
        extras: extras,
        viaKeyboard: viaKeyboard,
      );
      return;
    }
    openSongModal(
      context,
      ref,
      song: item,
      viaKeyboard: viaKeyboard,
      extras: extras,
      onQueueAction: (action) {
        if (!mounted) return;
        enqueueLoaded(ref, context, action, [
          trackFromRow(item, ref.read(coverCacheDirectoryProvider)),
        ], item.title);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final path = widget.path;
    if (path == null || path.isEmpty) {
      return PageScaffold(
        title: l10n.historyTrackTitle,
        body: EmptyState(
          icon: AppIcons.history,
          title: l10n.historyTrackNotFound,
        ),
      );
    }
    final page = ref.watch(historyTrackProvider(path));
    final data = page.value;
    if (data == null) {
      return PageScaffold(
        title: l10n.historyTrackTitle,
        body: page.hasError
            ? const HistoryLoadFailed()
            : ref.watch(libraryDatabaseProvider) == null
            ? const HistoryUnavailable()
            : const LibraryLoading(),
      );
    }
    final summary = data.summary;
    final track = summary.track;
    final details = [
      track?.artist,
      track?.album,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return PageScaffold(
      title: track?.title ?? path.split('/').last,
      subtitle: track == null
          ? l10n.playlistNotInLibrary
          : details.isEmpty
          ? null
          : details,
      body: Column(
        children: [
          HistoryTrackHeader(
            summary: summary,
            onPlay: track == null ? null : () => _play(summary),
          ),
          Expanded(
            child: data.plays.isEmpty
                ? EmptyState(
                    icon: AppIcons.history,
                    title: l10n.historyTrackNoPlays,
                  )
                : ListView.builder(
                    itemExtent: historyTrackRowExtent,
                    itemCount: data.plays.length,
                    itemBuilder: (context, i) => HistoryTrackPlayTile(
                      row: data.plays[i],
                      onMenu: ({required viaKeyboard, required at}) =>
                          _openModal(
                            summary,
                            data.plays[i],
                            viaKeyboard: viaKeyboard,
                          ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
