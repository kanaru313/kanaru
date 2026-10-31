import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';

import '../../shared/song_modal/song_modal_test_support.dart';
import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _tracks = [
  TestTrack('solo', artist: 'Ann', album: 'Al'),
  TestTrack('duet', artist: 'Ann; Bob', album: 'Al'),
];

void main() {
  Future<void> openMenu(WidgetTester tester, String row) =>
      openSongModal(tester, find.text(row));

  testWidgets('Go to album goes to the album page and closes the modal', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tapModalAction(tester, 'Go to album');

    expect(location(h), albumLocation(const AlbumKey('ann', 'al')));
    expect(modalAction('album'), findsNothing);
  });

  testWidgets('Go to folder goes to the folder page', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, [
      const TestTrack('solo', artist: 'Ann', path: '/m/A/x.flac'),
    ], location: '/songs');

    await openMenu(tester, 'solo');
    await tapModalAction(tester, 'Go to folder');

    expect(location(h), folderLocation('/m/A'));
    expect(find.text('A'), findsWidgets);
  });

  testWidgets('Go to folder of a song removed while the modal was open says '
      'so', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tester.runAsync(() => h.db.delete(h.db.tracks).go());
    await tester.pump();
    await tapModalAction(tester, 'Go to folder');

    expect(find.text('This song is no longer in the library'), findsOneWidget);
    expect(location(h), '/songs');
  });

  testWidgets('Go to artist of a song with one artist goes to the artist', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tapModalAction(tester, 'Go to artist');

    expect(location(h), artistLocation('ann'));
  });

  testWidgets('a song with two artists lists them as chips', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'duet');
    expect(find.text('2 artists'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(location(h), '/songs', reason: 'nothing chosen yet');

    await tapModalAction(tester, 'Bob');

    expect(location(h), artistLocation('bob'));
  });

  testWidgets('Go to artist of a song removed while the modal was open says '
      'so', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tester.runAsync(() => h.db.delete(h.db.tracks).go());
    await tester.pump();
    await tapModalAction(tester, 'Go to artist');

    expect(find.text('This song is no longer in the library'), findsOneWidget);
    expect(location(h), '/songs');
  });

  testWidgets(
    'Go to album of a song removed while the modal was open says so',
    (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/songs');

      await openMenu(tester, 'solo');
      await tester.runAsync(() => h.db.delete(h.db.tracks).go());
      await tester.pump();
      await tapModalAction(tester, 'Go to album');

      expect(
        find.text('This song is no longer in the library'),
        findsOneWidget,
      );
      expect(location(h), '/songs');
    },
  );

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
    await tester.tap(find.byTooltip('Show in file manager'));
    await settleSongModal(tester);

    expect(shown, hasLength(1));
    expect(shown.single, startsWith('/m/'));
    expect(find.text("Couldn't open the file manager"), findsNothing);
    expect(modalAction('folder'), findsNothing);
  });

  testWidgets('a file manager that fails is reported', (tester) async {
    final h = LibraryHarness(
      overrides: [
        showInFileManagerProvider.overrideWithValue((_) async => false),
      ],
    );
    await openWithTracks(tester, h, _tracks, location: '/songs');

    await openMenu(tester, 'solo');
    await tester.tap(find.byTooltip('Show in file manager'));
    await settleSongModal(tester);

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
    await tapModalAction(tester, 'Go to album');

    expect(find.text('This song has no album'), findsOneWidget);
    expect(location(h), '/songs');
  });
}
