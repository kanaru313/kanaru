import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _tracks = [
  TestTrack('solo', artist: 'Ann', album: 'Al'),
  TestTrack('duet', artist: 'Ann; Bob', album: 'Al'),
];

void main() {
  Future<void> openMenu(WidgetTester tester, String row) async {
    await tester.tap(find.text(row), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  testWidgets('Show album goes to the album page', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tester.tap(find.text('Show album'));
    await tester.pumpAndSettle();

    expect(location(h), albumLocation(const AlbumKey('ann', 'al')));
  });

  testWidgets('Show in folder goes to the folder page', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, [
      const TestTrack('solo', artist: 'Ann', path: '/m/A/x.flac'),
    ], location: '/songs');

    await openMenu(tester, 'solo');
    await tester.tap(find.text('Show in folder'));
    await tester.pumpAndSettle();

    expect(location(h), folderLocation('/m/A'));
    expect(find.text('A'), findsWidgets);
  });

  testWidgets('Show in folder of a song removed while the menu was open says '
      'so', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tester.runAsync(() => h.db.delete(h.db.tracks).go());
    await tester.pump();
    await tester.tap(find.text('Show in folder'));
    await tester.pumpAndSettle();

    expect(find.text('This song is no longer in the library'), findsOneWidget);
    expect(location(h), '/songs');
  });

  testWidgets('Show artist of a song with one artist goes to the artist', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tester.tap(find.text('Show artist'));
    await tester.pumpAndSettle();

    expect(location(h), artistLocation('ann'));
  });

  testWidgets('Show artist of a song with two artists asks which', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'duet');
    await tester.tap(find.text('Show artist'));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
    expect(location(h), '/songs', reason: 'nothing chosen yet');

    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    expect(location(h), artistLocation('bob'));
  });

  testWidgets('a song removed while its menu was open says so', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tester.runAsync(() => h.db.delete(h.db.tracks).go());
    await tester.pump();
    await tester.tap(find.text('Show artist'));
    await tester.pumpAndSettle();

    expect(find.text('This song is no longer in the library'), findsOneWidget);
  });

  testWidgets('Show in file manager hands over the song path', (tester) async {
    final shown = <String>[];
    final h = LibraryHarness(
      overrides: [
        showInFileManagerProvider.overrideWithValue((path) async {
          shown.add(path);
          return true;
        }),
      ],
    );
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tester.tap(find.text('Show in file manager'));
    await tester.pumpAndSettle();

    expect(shown, hasLength(1));
    expect(shown.single, startsWith('/m/'));
    expect(find.text("Couldn't open the file manager"), findsNothing);
  });

  testWidgets('a file manager that fails is reported', (tester) async {
    final h = LibraryHarness(
      overrides: [
        showInFileManagerProvider.overrideWithValue((_) async => false),
      ],
    );
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tester.tap(find.text('Show in file manager'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't open the file manager"), findsOneWidget);
  });

  testWidgets('a song whose album tag was cleared says it has none', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tester.runAsync(
      () => h.db.customStatement(
        "UPDATE tracks SET album_title_key = NULL WHERE title = 'solo'",
      ),
    );
    await tester.tap(find.text('Show album'));
    await tester.pumpAndSettle();

    expect(find.text('This song has no album'), findsOneWidget);
    expect(location(h), '/songs');
  });

  testWidgets('a song whose artist tag was cleared says it has none', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tester.runAsync(
      () => h.db.customStatement(
        "UPDATE tracks SET artist = NULL WHERE title = 'solo'",
      ),
    );
    await tester.tap(find.text('Show artist'));
    await tester.pumpAndSettle();

    expect(find.text('This song has no artist'), findsOneWidget);
  });
}
