import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_startup.dart';
import '../../database/lyrics_plugin_queries.dart';

/// What one plugin keeps: its own storage and the lyrics saved from it.
typedef PluginDataStats = ({int storageBytes, int foundCount, int textBytes});

/// The data of the plugin [installId], read when asked. Callers invalidate it
/// after they delete some of that data. Without a library database there is
/// nothing stored, so every number is zero.
final pluginDataStatsProvider = FutureProvider.autoDispose
    .family<PluginDataStats, String>((ref, installId) async {
      final db = ref.watch(libraryDatabaseProvider);
      if (db == null) return (storageBytes: 0, foundCount: 0, textBytes: 0);
      return db.lyricsPluginDataStats(installId);
    });
