import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/history_rows.dart';
import '../../core/database/library_startup.dart';
import '../../core/indexer/cover_paths.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/play_tracks.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/library_loading.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'history_delete_undo.dart';
import 'history_play_menu.dart';
import 'history_plays_version.dart';
import 'history_providers.dart';
import 'history_screen_states.dart';
import 'history_track_header.dart';
import 'history_track_play_tile.dart';

/// The history page of one song, reached from the menu of a History row:
/// totals, then every play newest first. A play is removed through its row
/// menu, with Undo. The page stays when the last play goes.
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
  final _undo = HistoryDeleteUndo();

  void _play(HistoryTrackSummary summary) {
    final track = summary.track;
    if (track == null) return;
    playTracks(ref, [
      trackFromItem(
        path: track.path,
        title: track.title,
        artist: track.artist,
        durationMs: track.durationMs,
        artPath: coverPath(
          ref.read(coverCacheDirectoryProvider),
          track.coverKey,
        ),
      ),
    ], 0);
  }

  /// Opens the menu of [row]. The play is the one the menu was opened on:
  /// the list may move before a choice is made.
  Future<void> _openMenu(
    HistoryTrackSummary summary,
    HistoryPlayRow row,
    Offset position,
  ) async {
    final choice = await showHistoryPlayMenu(
      context,
      position,
      canQueue: summary.track != null,
      canShowTrackHistory: false,
    );
    if (choice != HistoryPlayChoice.delete || !mounted) return;
    final db = ref.read(libraryDatabaseProvider);
    if (db == null) return;
    unawaited(
      _undo.delete(
        db: db,
        messenger: ScaffoldMessenger.of(context),
        l10n: context.l10n,
        version: ref.read(historyPlaysVersionProvider.notifier),
        playId: row.id,
      ),
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
          ? l10n.historyTrackMissing
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
                      onMenu: (position) => unawaited(
                        _openMenu(summary, data.plays[i], position),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
