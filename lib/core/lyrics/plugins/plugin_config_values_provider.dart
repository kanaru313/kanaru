import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_database.dart';
import '../../database/library_startup.dart';
import '../../database/lyrics_plugin_data_queries.dart';
import 'store/plugin_config_values.dart';

/// The non-secret config values of one plugin, live: emits again only when
/// they change (a write to the script's storage does not). Secrets are not in
/// it. Empty without a library database.
final pluginStoredConfigProvider = StreamProvider.autoDispose
    .family<Map<String, Object?>, String>((ref, installId) {
      final LibraryDatabase? db = ref.watch(libraryDatabaseProvider);
      if (db == null) return Stream.value(const {});
      return db
          .watchLyricsPluginConfigValuesText(installId)
          .map(decodeStoredPluginConfig);
    }, retry: (_, _) => null);
