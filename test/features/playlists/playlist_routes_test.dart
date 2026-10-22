import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/features/playlists/favorites_routes.dart';
import 'package:kanaru/features/playlists/playlist_routes.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

void main() {
  test('the route literal matches the destination', () {
    expect(playlistsPath, AppDestination.playlists.path);
    expect(playlistLocation(3), '/playlists/3');
    expect(favoritesPath, AppDestination.favorites.path);
  });

  test('only a positive whole number is a playlist id', () {
    expect(parsePlaylistRouteId('3'), 3);
    expect(parsePlaylistRouteId('42'), 42);
    for (final bad in [
      '0',
      '-1',
      'x',
      '3a',
      '',
      ' 3',
      '3.5',
      '99999999999999999999',
    ]) {
      expect(parsePlaylistRouteId(bad), isNull, reason: bad);
    }
  });

  group('not found', () {
    for (final id in ['abc', '999', '0']) {
      testWidgets('/playlists/$id', (tester) async {
        final h = LibraryHarness(refreshInterval: Duration.zero);
        await openApp(tester, h, ['a'], location: '/playlists/$id');

        expect(find.text('Playlist not found'), findsOneWidget);
        expect(find.text('It may have been deleted.'), findsOneWidget);
      });
    }
  });

  testWidgets('without a library the pages say so', (tester) async {
    final h = LibraryHarness(hasDatabase: false);
    await h.pump(tester);
    goTo(tester, h, '/playlists/1');
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open the library"), findsOneWidget);

    goTo(tester, h, '/playlists');
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open the library"), findsOneWidget);
  });
}
