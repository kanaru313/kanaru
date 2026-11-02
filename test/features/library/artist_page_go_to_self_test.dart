import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/library_grid/album_grid_tile.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/song_modal/song_modal_test_support.dart';
import 'browse_test_data.dart';
import 'library_test_harness.dart';

/// Ann alone on "Mine"; Ann with Bob on "Theirs", Bob's album.
const _tracks = [
  TestTrack(
    'solo song',
    artist: 'Ann',
    album: 'Mine',
    albumArtist: 'Ann',
    genre: 'Rock',
  ),
  TestTrack(
    'duet song',
    artist: 'Ann; Bob',
    album: 'Theirs',
    albumArtist: 'Bob',
    genre: 'Rock',
  ),
];

/// Scrolls the page until [target] shows; the song list builds lazily.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openSongModalOf(WidgetTester tester, String title) async {
  final row = find.widgetWithText(SongTile, title);
  await _reveal(tester, row);
  await openSongModal(tester, row);
}

Future<void> _openAlbumModalOf(WidgetTester tester, String title) async {
  final tile = find.widgetWithText(AlbumGridTile, title);
  await _reveal(tester, tile);
  await tester.tap(tile, buttons: kSecondaryButton);
  await settleModal(tester);
}

/// The subtitle under the Go to artist row of the open modal.
Finder _artistNamed(String name) =>
    find.descendant(of: modalAction('artist'), matching: find.text(name));

void main() {
  group("on an artist's page", () {
    testWidgets('a song by that artist alone has no Go to artist', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: artistLocation('ann'));

      await _openSongModalOf(tester, 'solo song');

      expect(modalAction('album'), findsOneWidget, reason: 'links loaded');
      expect(modalAction('artist'), findsNothing);
      expect(modalAction('artists'), findsNothing);
    });

    testWidgets('a song with another artist goes to the other only', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: artistLocation('ann'));

      await _openSongModalOf(tester, 'duet song');

      expect(modalAction('artists'), findsNothing);
      expect(_artistNamed('Bob'), findsOneWidget);
      await tapModalAction(tester, 'Go to artist');
      expect(location(h), artistLocation('bob'));
    });

    testWidgets('the Albums shelf: an album of that artist alone has no Go '
        'to artist', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: artistLocation('ann'));

      await _openAlbumModalOf(tester, 'Mine');

      expect(modalAction('folder'), findsOneWidget, reason: 'links loaded');
      expect(modalAction('artist'), findsNothing);
      expect(modalAction('artists'), findsNothing);
    });

    testWidgets('the Appears on shelf: an album of another artist keeps it', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: artistLocation('ann'));

      await _openAlbumModalOf(tester, 'Theirs');

      expect(_artistNamed('Bob'), findsOneWidget);
    });
  });

  testWidgets('on a genre page the song keeps Go to artist', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: genreLocation('rock'));

    await _openSongModalOf(tester, 'solo song');

    expect(_artistNamed('Ann'), findsOneWidget);
  });

  testWidgets('in the Songs list the song keeps every artist', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openSongModal(tester, find.widgetWithText(SongTile, 'duet song'));

    expect(modalAction('artists'), findsOneWidget);
    expect(find.text('2 artists'), findsOneWidget);
  });
}
