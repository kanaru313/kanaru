import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_providers.dart';

import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';
import '../../features/playlists/playlist_test_data.dart';
import '../song_modal/song_modal_test_support.dart';

const _tracks = [TestTrack('a'), TestTrack('b')];

void main() {
  Future<void> openMenu(WidgetTester tester, String title) =>
      openSongModal(tester, find.text(title));

  testWidgets('a song not yet liked is added from its modal', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');
    final path = (await trackPaths(tester, h))['b']!;

    await openMenu(tester, 'b');
    expect(find.text('Remove from favorites'), findsNothing);
    expect(find.text('Add to favorites'), findsOneWidget);
    await tapModalAction(tester, 'Add to favorites');
    await settleDb(tester);

    expect(find.text('Added to Favorites'), findsOneWidget);
    expect(await tester.runAsync(() => h.db.isFavorite(path)), isTrue);
  });

  testWidgets('a liked song is removed from its modal', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');
    final path = (await trackPaths(tester, h))['a']!;
    await tester.runAsync(() => h.db.setFavorite(path, favorite: true, now: 1));

    await openMenu(tester, 'a');
    expect(find.text('Add to favorites'), findsNothing);
    await tapModalAction(tester, 'Remove from favorites');
    await settleDb(tester);

    expect(find.text('Removed from Favorites'), findsOneWidget);
    expect(await tester.runAsync(() => h.db.isFavorite(path)), isFalse);
  });

  testWidgets('the modal reads the database, not a paused stream', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');
    final path = (await trackPaths(tester, h))['a']!;
    // Read once, then left with no listener (no heart on screen).
    final sub = h.container.listen(favoritePathsProvider, (_, _) {});
    await settleDb(tester);
    sub.close();
    await settleDb(tester);

    await tester.runAsync(() => h.db.setFavorite(path, favorite: true, now: 1));
    await openMenu(tester, 'a');

    expect(find.text('Remove from favorites'), findsOneWidget);
  });
}
