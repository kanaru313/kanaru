import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_database.dart' show TrackListItem;
import '../../../core/database/library_startup.dart';
import '../../../core/indexer/indexer_providers.dart';
import '../../../core/indexer/indexer_state.dart';
import '../../../core/player/player_service.dart';
import '../../../core/player/track.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../directory_picker_provider.dart';
import '../root_rejection_message.dart';
import 'scan_progress_bar.dart';
import 'scan_result_snack_bar.dart';
import 'song_tile.dart';
import 'songs_empty_view.dart';
import 'songs_list_provider.dart';

/// The scanned library as a flat list, with scan progress and a rescan
/// button. Tapping a song plays the whole list from it.
class SongsScreen extends ConsumerWidget {
  /// [pickDirectory] opens the folder picker; defaults to
  /// [directoryPickerProvider].
  const SongsScreen({super.key, this.pickDirectory});

  final DirectoryPicker? pickDirectory;

  void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Adds a folder picked right here (no detour through the welcome screen)
  /// and scans it.
  Future<void> _chooseFolder(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final controller = ref.read(libraryRootsControllerProvider);
    final scan = ref.read(libraryIndexerProvider.notifier).scan;
    final DirectoryPicker pick =
        pickDirectory ?? ref.read(directoryPickerProvider);
    final path = await pick();
    if (path == null || !context.mounted) return;
    final result = await controller.addRoots([path]);
    if (!context.mounted) return;
    if (result.rejected.isNotEmpty) {
      final first = result.rejected.entries.first;
      _showMessage(context, rootRejectionMessage(l10n, first.key, first.value));
      return;
    }
    unawaited(scan()); // failures land in the indexer state
  }

  void _play(WidgetRef ref, List<TrackListItem> songs, int index) {
    final tracks = [
      for (final s in songs)
        Track(
          uri: s.path,
          title: s.title,
          artist: s.artist,
          duration: s.durationMs == null
              ? null
              : Duration(milliseconds: s.durationMs!),
        ),
    ];
    unawaited(
      ref.read(playerServiceProvider.notifier).openTracks(tracks, start: index),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.listen(libraryIndexerProvider, (previous, next) {
      final snackBar = scanResultSnackBar(context, next);
      if (snackBar == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);
    });

    final hasDb = ref.watch(libraryDatabaseProvider) != null;
    final hasRoots = ref.watch(libraryHasRootsProvider);
    final scan = ref.watch(libraryIndexerProvider);
    final scanning = scan is IndexerScanning;
    final songs = ref.watch(songsListProvider).value ?? const [];

    final Widget body;
    if (!hasDb) {
      body = const SongsEmptyView(kind: SongsEmptyKind.unavailable);
    } else if (!hasRoots) {
      body = SongsEmptyView(
        kind: SongsEmptyKind.noRoots,
        onChooseFolder: () => _chooseFolder(context, ref),
      );
    } else {
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
            child: Row(
              children: [
                Expanded(
                  child: scan is IndexerScanning
                      ? ScanProgressBar(state: scan)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: scanning
                      ? null
                      : () => unawaited(
                          ref.read(libraryIndexerProvider.notifier).scan(),
                        ),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.libraryRescan),
                ),
              ],
            ),
          ),
          Expanded(
            child: songs.isNotEmpty
                ? ListView.builder(
                    itemExtent: songTileExtent,
                    itemCount: songs.length,
                    itemBuilder: (context, i) => SongTile(
                      song: songs[i],
                      onTap: () => _play(ref, songs, i),
                    ),
                  )
                : scanning
                ? const SizedBox.shrink()
                : const SongsEmptyView(kind: SongsEmptyKind.noTracks),
          ),
        ],
      );
    }

    return PageScaffold(title: l10n.navSongs, body: body);
  }
}
