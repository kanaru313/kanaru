import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/library_keys_provider.dart';
import '../../../../core/database/library_startup.dart';
import '../folder_songs.dart';

/// Resolved counts and total duration of a folder, used by the folder context modal.
typedef FolderStats = ({int durationMs, int songCount, String? samplePath});

/// The statistics of one folder: reads the folder's songs in the background and
/// computes their total duration and song count, with a sample path for cover art.
///
/// Recomputed when [keysReadyProvider] or [libraryDatabaseProvider] changes.
/// Null without a library or when the folder holds no songs.
final folderModalStatsProvider = FutureProvider.autoDispose
    .family<FolderStats?, ({String path, bool direct})>((ref, arg) async {
      ref.watch(keysReadyProvider);
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return null;
      final songs = await readFolderSongs(db, arg.path, recursive: !arg.direct);
      if (songs.isEmpty) return null;
      final durationMs = songs.fold<int>(
        0,
        (sum, s) => sum + (s.durationMs ?? 0),
      );
      return (
        durationMs: durationMs,
        songCount: songs.length,
        samplePath: songs.firstOrNull?.path,
      );
    });
