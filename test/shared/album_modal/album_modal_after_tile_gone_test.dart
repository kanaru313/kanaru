import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' show AlbumKey;
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/shared/widgets/library_grid/album_tile_data.dart';

import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';
import 'album_modal_test_support.dart';

const _tracks = [
  TestTrack('a1', artist: 'Ann', album: 'Alpha', track: 1),
  TestTrack('a2', artist: 'Ann', album: 'Alpha', track: 2),
  TestTrack('b1', artist: 'Bob', album: 'Beta', track: 1),
];
const _alpha = AlbumTileData(
  key: AlbumKey('ann', 'alpha'),
  title: 'Alpha',
  artist: 'Ann',
);

void main() {
  List<String> queue(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.tracks)
      t.title,
  ];

  /// Opens the modal of the album, removes its tile, then taps [label].
  Future<(LibraryHarness, AlbumHost)> run(
    WidgetTester tester,
    String label, {
    bool tooltip = false,
    List<String>? fileManager,
  }) async {
    final h = LibraryHarness(
      overrides: [
        if (fileManager != null)
          showInFileManagerProvider.overrideWithValue((path) async {
            fileManager.add(path);
            return true;
          }),
      ],
    );
    await openWithTracks(tester, h, _tracks, location: '/albums');
    final host = await pumpAlbumHost(
      tester,
      container: h.container,
      album: _alpha,
      enqueueForReal: true,
    );
    await tester.pumpAndSettle();
    await openAlbumModalOf(tester);
    host.shown.value = false;
    await tester.pump();
    expect(find.text('tile'), findsNothing);

    await tester.tap(tooltip ? find.byTooltip(label) : find.text(label));
    await settleIo(tester, h);
    return (h, host);
  }

  testWidgets('Play next queues the album and says so', (tester) async {
    final (h, _) = await run(tester, 'Play next');
    expect(queue(h), ['a1', 'a2']);
    expect(find.text('Playing: Alpha'), findsOneWidget);
  });

  testWidgets('Add to queue queues the album', (tester) async {
    final (h, _) = await run(tester, 'Add to queue');
    expect(queue(h), ['a1', 'a2']);
  });

  testWidgets('Play all plays the album in order', (tester) async {
    final (h, _) = await run(tester, 'Play all');
    expect(queue(h), ['a1', 'a2']);
    expect(h.container.read(playerServiceProvider).queue.shuffled, isFalse);
  });

  testWidgets('Shuffle plays the album shuffled', (tester) async {
    final (h, _) = await run(tester, 'Shuffle');
    expect(queue(h).toSet(), {'a1', 'a2'});
    expect(h.container.read(playerServiceProvider).queue.shuffled, isTrue);
  });

  testWidgets('Add to playlist opens the picker after the tile is gone', (
    tester,
  ) async {
    await run(tester, 'Add to playlist…');
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final root = Navigator.of(tester.element(dialog), rootNavigator: true);
    expect(Navigator.of(tester.element(dialog)), same(root));
  });

  testWidgets('Go to artist navigates after the tile is gone', (tester) async {
    final (_, host) = await run(tester, 'Go to artist');
    expect(host.location, artistLocation('ann'));
  });

  testWidgets('Go to folder navigates after the tile is gone', (tester) async {
    final (_, host) = await run(tester, 'Go to folder');
    expect(host.location, startsWith('$foldersPath/'));
  });

  testWidgets('Show in file manager gets a track path after the tile is gone', (
    tester,
  ) async {
    final opened = <String>[];
    await run(
      tester,
      'Show in file manager',
      tooltip: true,
      fileManager: opened,
    );
    expect(opened, hasLength(1));
    expect(opened.single, endsWith('.flac'));
  });
}
