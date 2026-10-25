import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/features/playlists/playlist_entry_tile.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/favorite_button.dart';

import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

/// Rows of the Favorites page: no remove button and no number, a handle, and
/// the row heart as the only way to take a song out.
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

  Finder rowHeart(int row) => find.descendant(
    of: find.byType(PlaylistEntryTile).at(row),
    matching: find.byType(FavoriteButton),
  );

  testWidgets('rows have a handle, a heart and no remove button or number', (
    tester,
  ) async {
    await openApp(tester, h, ['a', 'b'], location: '/favorites');
    await like(tester, ['a', 'b']);

    expect(shownTitles(tester), ['a', 'b']);
    expect(find.byIcon(AppIcons.dragHandle), findsNWidgets(2));
    expect(find.byTooltip('Remove from playlist'), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(rowHeart(0), findsOneWidget);
  });

  testWidgets('hovering a row does not bring a remove button', (tester) async {
    await openApp(tester, h, ['a'], location: '/favorites');
    await like(tester, ['a']);

    await hoverRow(tester, 0);

    expect(find.byTooltip('Remove from playlist'), findsNothing);
  });

  testWidgets('the heart of a row unlikes it and the row goes', (tester) async {
    await openApp(tester, h, ['a', 'b'], location: '/favorites');
    await like(tester, ['a', 'b']);
    final paths = await trackPaths(tester, h);

    await tester.tap(rowHeart(0));
    await settleDb(tester);

    expect(shownTitles(tester), ['b']);
    expect(await tester.runAsync(() => h.db.isFavorite(paths['a']!)), isFalse);
  });

  testWidgets('an unlike during a drag shows only after the drop', (
    tester,
  ) async {
    await openApp(tester, h, ['a', 'b', 'c'], location: '/favorites');
    await like(tester, ['a', 'b', 'c']);
    final paths = await trackPaths(tester, h);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(AppIcons.dragHandle).first),
    );
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.runAsync(
      () => h.db.setFavorite(paths['c']!, favorite: false, now: 2),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(shownTitles(tester), contains('c'), reason: 'not under the hand');

    await gesture.up();
    await settleDb(tester);

    expect(shownTitles(tester), isNot(contains('c')));
    expect(playlistSongCount('2 songs'), findsOneWidget);
  });

  testWidgets('a liked file that left the library shows a heart that unlikes', (
    tester,
  ) async {
    await openApp(tester, h, ['a'], location: '/favorites');
    const gone = '/gone/lost.mp3';
    await tester.runAsync(() => h.db.setFavorite(gone, favorite: true, now: 1));
    await like(tester, ['a']);

    expect(find.text('lost.mp3'), findsOneWidget);
    expect(find.text('Not in library'), findsOneWidget);
    expect(find.byTooltip('Remove from playlist'), findsNothing);
    final heart = find.descendant(
      of: find.ancestor(
        of: find.text('lost.mp3'),
        matching: find.byType(PlaylistEntryTile),
      ),
      matching: find.byType(FavoriteButton),
    );
    expect(heart, findsOneWidget);

    await tester.tap(heart);
    await settleDb(tester);

    expect(find.text('lost.mp3'), findsNothing);
    expect(shownTitles(tester), ['a']);
    expect(await tester.runAsync(() => h.db.isFavorite(gone)), isFalse);
  });
}
