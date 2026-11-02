import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_rows.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/playlist_providers.dart';
import 'package:kanaru/core/player/playing_track_path.dart';
import 'package:kanaru/features/history/history_play_row_tile.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/song_modal/song_modal_extras.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late LibraryDatabase db;
  setUp(() => db = LibraryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const path = '/music/t1.flac';
  HistoryPlayRow row({required bool latest}) => HistoryPlayRow(
    id: 1,
    path: path,
    playedAt: DateTime(2026, 1, 2, 3, 4).millisecondsSinceEpoch,
    nth: 3,
    latest: latest,
    track: const TrackListItem(
      id: 1,
      path: path,
      title: 'T1',
      artist: 'Artist 1',
      album: 'Album 1',
      durationMs: 62000,
    ),
  );

  /// Pumps one tile and returns the colour of its "#3" badge text.
  Future<Color?> badgeColor(
    WidgetTester tester, {
    required bool latest,
    required String playingPath,
  }) async {
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
            body: SizedBox(
              height: 120,
              child: HistoryPlayRowTile(
                row: row(latest: latest),
                onTap: () {},
                onMenu: ({required viaKeyboard, required at}) {},
                onQueueAction: (_) {},
                modalExtras: () => const SongModalExtras(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<Text>(find.text('#3')).style?.color;
  }

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(HistoryPlayRowTile))).colorScheme;

  testWidgets('badge is onPrimaryContainer on the newest play of the playing '
      'track', (tester) async {
    final color = await badgeColor(tester, latest: true, playingPath: path);
    expect(color, schemeOf(tester).onPrimaryContainer);
  });

  testWidgets('badge of an older play of the playing track stays muted', (
    tester,
  ) async {
    final color = await badgeColor(tester, latest: false, playingPath: path);
    expect(color, schemeOf(tester).onSurfaceVariant);
  });

  testWidgets('badge stays muted when another track is playing', (
    tester,
  ) async {
    final color = await badgeColor(
      tester,
      latest: true,
      playingPath: '/music/other.flac',
    );
    expect(color, schemeOf(tester).onSurfaceVariant);
  });
}
