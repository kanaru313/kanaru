import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/playlist_providers.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/core/player/playing_track_path.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/song_row_view.dart';
import 'package:material_ui/material_ui.dart';

import 'playlist_entries_view_harness.dart' show available;

void main() {
  late LibraryDatabase db;
  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  PlaylistEntryRow copy(PlaylistEntryRow e, int id, {required bool repeat}) =>
      PlaylistEntryRow(
        entryId: id,
        path: e.path,
        track: e.track,
        repeat: repeat,
      );

  Future<List<bool>> playingFlags(
    WidgetTester tester,
    List<PlaylistEntryRow> entries,
    String playingPath,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryDatabaseProvider.overrideWithValue(db),
          favoritePathsProvider.overrideWith((ref) => Stream.value(const {})),
          playingTrackPathProvider.overrideWithValue(playingPath),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  SizedBox(
                    height: 120,
                    child: PlaylistEntryTile(
                      key: ValueKey(entries[i].entryId),
                      entry: entries[i],
                      index: i,
                      reorderable: false,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return [
      for (final v in tester.widgetList<SongRowView>(find.byType(SongRowView)))
        v.playing,
    ];
  }

  testWidgets('only the first copy of the playing song is marked', (
    tester,
  ) async {
    final a = available(1);
    final b = available(2);
    final flags = await playingFlags(tester, [
      a,
      b,
      copy(a, 3, repeat: true),
    ], a.path);

    expect(flags, [true, false, false]);
  });

  testWidgets('a lone second copy in a filtered list is not marked', (
    tester,
  ) async {
    final a = available(1);
    final flags = await playingFlags(tester, [
      copy(a, 3, repeat: true),
    ], a.path);

    expect(flags, [false]);
  });
}
