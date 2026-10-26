import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/features/playlists/favorites_screen.dart';
import 'package:kanaru/features/playlists/playlist_details.dart';
import 'package:kanaru/features/playlists/playlist_routes.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart' show goTo;
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  Future<void> like(WidgetTester tester, List<String> titles) async {
    final paths = await trackPaths(tester, h);
    for (final title in titles) {
      await tester.runAsync(
        () => h.db.setFavorite(paths[title]!, favorite: true, now: 1),
      );
    }
    await settleDb(tester);
  }

  // The name sits in the side pane or the header, whichever width the page
  // has.
  Finder rowTitle(String text) => find.descendant(
    of: find.byType(PlaylistDetails),
    matching: find.text(text),
  );

  Future<void> openHeaderMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Playlist actions'));
    await tester.pumpAndSettle();
  }

  testWidgets('before the first like it says how to fill it', (tester) async {
    await openApp(tester, h, ['a'], location: '/favorites');

    expect(find.text('Songs you like will show up here.'), findsOneWidget);
    expect(find.text('Favorites'), findsWidgets);
  });

  testWidgets('is called Yêu thích in Vietnamese', (tester) async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [libraryDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FavoritesScreen(),
        ),
      ),
    );
    await settleDb(tester);

    expect(find.text('Yêu thích'), findsNWidgets(2));
    expect(find.text('Bài hát bạn thích sẽ hiện ở đây.'), findsOneWidget);
    // Let the stream queries close before the database does.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('lists the liked songs with no rename or delete', (tester) async {
    await openApp(tester, h, ['a', 'b', 'c'], location: '/favorites');
    await like(tester, ['b', 'a']);

    expect(shownTitles(tester), ['b', 'a']);
    expect(rowTitle('Favorites'), findsOneWidget);
    expect(playlistSongCount('2 songs'), findsOneWidget);
    expect(find.byTooltip('Remove from favorites'), findsNWidgets(2));
    if (find.byTooltip('Playlist actions').evaluate().isNotEmpty) {
      await openHeaderMenu(tester);
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Delete playlist'), findsNothing);
    }
  });

  testWidgets('removing a row unlikes the song', (tester) async {
    await openApp(tester, h, ['a', 'b'], location: '/favorites');
    await like(tester, ['a', 'b']);
    final paths = await trackPaths(tester, h);

    await tester.tap(find.byTooltip('Remove from favorites').first);
    await settleDb(tester);

    expect(shownTitles(tester), ['b']);
    expect(await tester.runAsync(() => h.db.isFavorite(paths['a']!)), isFalse);
    expect(await tester.runAsync(() => h.db.isFavorite(paths['b']!)), isTrue);
  });

  testWidgets('unliking everything shows the favorites empty message', (
    tester,
  ) async {
    await openApp(tester, h, ['a'], location: '/favorites');
    await like(tester, ['a']);
    final paths = await trackPaths(tester, h);

    await tester.runAsync(
      () => h.db.setFavorite(paths['a']!, favorite: false, now: 1),
    );
    await settleDb(tester);

    expect(find.text('Songs you like will show up here.'), findsOneWidget);
  });

  testWidgets('its playlist URL shows it the same way', (tester) async {
    await openApp(tester, h, ['a']);
    await like(tester, ['a']);
    final id = (await tester.runAsync(h.db.favoritesPlaylistId))!;

    goTo(tester, h, playlistLocation(id));
    await settleDb(tester);

    expect(rowTitle('Favorites'), findsOneWidget);
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
  });

  testWidgets('an ordinary playlist keeps rename and delete', (tester) async {
    await openApp(tester, h, ['a']);
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    goTo(tester, h, playlistLocation(id));
    await settleDb(tester);

    await openHeaderMenu(tester);

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete playlist'), findsOneWidget);
  });
}
