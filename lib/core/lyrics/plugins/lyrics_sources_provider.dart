import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/library_database.dart';
import '../../database/library_startup.dart';
import '../../database/lyrics_plugin_queries.dart';
import 'lyrics_plugin_record.dart';
import 'lyrics_sources_order.dart';

export 'lyrics_sources_order.dart';

/// The rows the source list is built from: every plugin record (removed ones
/// included) and every saved preference.
class LyricsSourcesInput {
  const LyricsSourcesInput(this.records, this.prefs);

  final List<LyricsPluginRecord> records;
  final List<LyricsSourcePrefRow> prefs;
}

/// The plugin records and the source preferences, emitted together. It emits
/// for the first time only after both tables have answered, and again only
/// when a row changed (the database streams fire on any write to a table).
/// Without a library database it emits once with nothing, so LRCLIB alone
/// runs. A failing stream ends in an error and the sources stay unloaded:
/// nothing is looked up from a list that may be wrong.
final lyricsSourcesInputProvider = StreamProvider<LyricsSourcesInput>((ref) {
  final db = ref.watch(libraryDatabaseProvider);
  if (db == null) {
    return Stream.value(const LyricsSourcesInput([], []));
  }
  return _combine(
    db.watchLyricsPluginRecords().distinct(listEquals),
    db.watchLyricsSourcePrefs().distinct(listEquals),
  );
}, retry: (_, _) => null);

Stream<LyricsSourcesInput> _combine(
  Stream<List<LyricsPluginRow>> rows,
  Stream<List<LyricsSourcePrefRow>> prefs,
) {
  late final StreamController<LyricsSourcesInput> out;
  StreamSubscription<void>? rowsSub;
  StreamSubscription<void>? prefsSub;
  List<LyricsPluginRow>? lastRows;
  List<LyricsSourcePrefRow>? lastPrefs;
  void emit() {
    final r = lastRows;
    final p = lastPrefs;
    if (r == null || p == null) return;
    out.add(
      LyricsSourcesInput([
        for (final row in r) LyricsPluginRecord.fromRow(row),
      ], p),
    );
  }

  out = StreamController<LyricsSourcesInput>(
    onListen: () {
      rowsSub = rows.listen((r) {
        lastRows = r;
        emit();
      }, onError: out.addError);
      prefsSub = prefs.listen((p) {
        lastPrefs = p;
        emit();
      }, onError: out.addError);
    },
    onCancel: () async {
      await rowsSub?.cancel();
      await prefsSub?.cancel();
    },
  );
  return out.stream;
}

/// Whether the source list has been read. Until it is, nothing is looked up
/// or sent, so a source still loading is not mistaken for a missing one.
final lyricsSourcesLoadedProvider = Provider<bool>(
  (ref) => ref.watch(lyricsSourcesInputProvider).hasValue,
);

/// Every source that exists (LRCLIB and the installed plugins), on or off,
/// in the user's order. Only LRCLIB until the list is loaded.
final lyricsSourcesProvider = Provider<List<LyricsSourceEntry>>((ref) {
  final input = ref.watch(lyricsSourcesInputProvider).value;
  return List.unmodifiable(
    orderLyricsSources(input?.records ?? const [], input?.prefs ?? const []),
  );
});

/// Every plugin record, removed ones included: the names of sources whose
/// stored lyrics may still be shown.
final lyricsPluginRecordsProvider = Provider<List<LyricsPluginRecord>>(
  (ref) => ref.watch(lyricsSourcesInputProvider).value?.records ?? const [],
);
