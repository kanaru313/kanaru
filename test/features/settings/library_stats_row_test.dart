import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/features/settings/library_stats_provider.dart';
import 'package:kanaru/features/settings/library_stats_row.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_test_harness.dart';

TracksCompanion _track(
  int rootId,
  String name, {
  String? album,
  String? genre = 'Rock',
}) => TracksCompanion.insert(
  rootId: rootId,
  path: '/m/$name.mp3',
  mtimeMs: 1,
  sizeBytes: 1,
  title: name,
  addedAt: 1,
  updatedAt: 1,
  artist: const Value('Ann'),
  album: Value(album),
  genre: Value(genre),
);

void main() {
  testWidgets('counts the library and follows it as tracks arrive', (
    tester,
  ) async {
    final h = LibraryHarness();
    final ids = await tester.runAsync(() => h.db.addRoots(['/m'], now: 1));
    await tester.runAsync(
      () => h.db.upsertTracks([
        _track(ids!.single, 'a', album: 'One'),
        _track(ids.single, 'b', album: 'One'),
      ]),
    );
    await h.pump(tester, hasRoots: true);
    await tester.tap(find.byTooltip('Settings'));
    await settleIo(tester, h);

    expect(find.text('In your library'), findsOneWidget);
    expect(
      find.text('2 tracks · 1 album · 1 artist · 1 genre'),
      findsOneWidget,
    );

    await tester.runAsync(
      () => h.db.upsertTracks([_track(ids!.single, 'c', album: 'Two')]),
    );
    await settleIo(tester, h);

    expect(
      find.text('3 tracks · 2 albums · 1 artist · 1 genre'),
      findsOneWidget,
    );
  });

  testWidgets('counts genres as the Genres list does', (tester) async {
    final h = LibraryHarness();
    final ids = await tester.runAsync(() => h.db.addRoots(['/m'], now: 1));
    await tester.runAsync(
      () => h.db.upsertTracks([
        _track(ids!.single, 'a', genre: 'Rock; Pop'),
        _track(ids.single, 'b', genre: ' rock '),
        _track(ids.single, 'c', genre: ' ; '),
        _track(ids.single, 'd', genre: null),
      ]),
    );
    await h.pump(tester, hasRoots: true);
    await tester.tap(find.byTooltip('Settings'));
    await settleIo(tester, h);

    // Rock and Pop: the tracks with no usable genre are not a genre.
    expect(
      find.text('4 tracks · 0 albums · 1 artist · 2 genres'),
      findsOneWidget,
    );
  });

  testWidgets('is hidden without a library database', (tester) async {
    final h = LibraryHarness(hasDatabase: false);
    await h.pump(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('In your library'), findsNothing);
    expect(find.text('Music folders'), findsOneWidget);
  });

  testWidgets('shows a dash, not the loading dots, when the count fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryStatsProvider.overrideWith(
            (ref) => Stream.error(StateError('no count')),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: LibraryStatsRow()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('In your library'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('…'), findsNothing);
  });
}
