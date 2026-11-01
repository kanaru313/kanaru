import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/play_history_writes.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/home/home_album_card.dart';
import 'package:kanaru/features/home/home_screen.dart';
import 'package:kanaru/shared/widgets/library_grid/album_grid_tile.dart';
import 'package:kanaru/shared/widgets/album_list_tile.dart';

import '../../features/home/home_test_harness.dart';
import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';
import 'album_modal_test_support.dart';

const _tracks = [
  TestTrack('a1', artist: 'Ann', album: 'Alpha', track: 1),
  TestTrack('a2', artist: 'Ann', album: 'Alpha', track: 2),
];

/// Row only the album modal has; the old popup lacked it.
final _album = albumModalAction('album');

void main() {
  testWidgets('an album grid tile opens the album modal', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');
    expect(find.byType(AlbumGridTile), findsOneWidget);

    await tester.tap(find.text('Alpha'), buttons: kSecondaryButton);
    await settleAlbumModal(tester);

    expect(_album, findsOneWidget);
  });

  testWidgets('an album list tile opens the album modal', (tester) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, _tracks, location: '/albums');
    h.container.read(settingsProvider.notifier).setAlbumsView(AlbumsView.list);
    await tester.pumpAndSettle();
    expect(find.byType(AlbumListTile), findsOneWidget);

    await tester.tap(find.text('Alpha'), buttons: kSecondaryButton);
    await settleAlbumModal(tester);

    expect(_album, findsOneWidget);
  });

  testWidgets('a Home album card opens the album modal', (tester) async {
    final h = HomeHarness();
    await h.addTrack('/a', artist: 'Ann', album: 'Alpha');
    await h.db.insertLibraryPlay(
      path: '/a',
      playedAt: DateTime.now().millisecondsSinceEpoch,
      listenedMs: 200000,
    );
    await h.pump(tester, const HomeScreen(), height: 2400);

    await tester.tap(
      find.descendant(
        of: find.byType(HomeAlbumCard),
        matching: find.text('Alpha'),
      ),
      buttons: kSecondaryButton,
    );
    await settleAlbumModal(tester);

    expect(_album, findsOneWidget);
  });
}
