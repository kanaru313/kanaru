import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/library_startup.dart';
import '../database/lyrics_plugin_queries.dart';
import '../lyrics/plugins/lyrics_plugin_record.dart';
import '../lyrics/plugins/lyrics_sources_provider.dart';

export '../lyrics/plugins/lyrics_plugin_record.dart';

/// The enabled source plugins: every record of kind source that is not
/// removed, in install order (a source plugin has no on/off switch).
/// Loading, a failed read and a missing database are told apart from "no
/// plugins": nothing is sent and nothing is swept until this has data.
///
/// - loading: the list is not read yet;
/// - error: the read failed, or there is no library database;
/// - data: the records.
final sourcePluginRecordsProvider =
    Provider<AsyncValue<List<LyricsPluginRecord>>>((ref) {
      if (ref.watch(libraryDatabaseProvider) == null) {
        return AsyncValue.error(
          StateError('library database unavailable'),
          StackTrace.empty,
        );
      }
      return ref
          .watch(lyricsSourcesInputProvider)
          .whenData(
            (input) => List.unmodifiable([
              for (final record in input.records)
                if (!record.isRemoved && record.kind == PluginKind.source)
                  record,
            ]),
          );
    });
