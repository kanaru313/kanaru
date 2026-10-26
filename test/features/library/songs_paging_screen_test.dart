import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_song_paging.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:kanaru/shared/widgets/song_tile_placeholder.dart';
import 'package:kanaru/features/library/songs/songs_list_provider.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';
import 'list_view_modes_override.dart';

String _name(int i) => 's${i.toString().padLeft(4, '0')}';

void main() {
  /// Lets the page reads that a scroll started finish.
  Future<void> settleRows(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets('any position of a large list can be scrolled to', (
    tester,
  ) async {
    final h = LibraryHarness(overrides: [listViewModesOverride]);
    await openWithTracks(tester, h, [
      for (var i = 0; i < 5000; i++) TestTrack(_name(i)),
    ], location: '/songs');
    await settleRows(tester);
    expect(find.text(_name(0)), findsOneWidget);
    final rowHeight = tester.getSize(find.byType(SongTile).first).height;

    final scrollable = tester.state<ScrollableState>(
      find.ancestor(
        of: find.byType(SongTile).first,
        matching: find.byType(Scrollable),
      ),
    );
    scrollable.position.jumpTo(rowHeight * 4000);
    await tester.pump();
    await settleRows(tester);

    expect(find.text(_name(4000)), findsOneWidget);
    expect(find.text(_name(0)), findsNothing);
    expect(
      find.byType(SongTilePlaceholder),
      findsNothing,
      reason: 'the rows on screen were read',
    );

    // The end of the list, a short last page.
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    await settleRows(tester);
    expect(find.text(_name(4999)), findsOneWidget);
    expect(find.byType(SongTilePlaceholder), findsNothing);
  });

  group('tap', () {
    // The ids snapshot does not refresh during the test: the library changes
    // between the list loading and the tap.
    LibraryHarness harness() => LibraryHarness(
      refreshInterval: const Duration(hours: 1),
      overrides: [listViewModesOverride],
    );

    Future<void> release(WidgetTester tester, LibraryHarness h) async {
      // The refresh timer must not outlive the test.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const SizedBox(),
        ),
      );
      await tester.pump();
      expect(h.container.exists(songIdsProvider), isFalse);
    }

    testWidgets('a track deleted before the tap plays nothing and says so', (
      tester,
    ) async {
      final h = harness();
      await openWithTracks(tester, h, const [
        TestTrack('a'),
        TestTrack('b'),
        TestTrack('c'),
      ], location: '/songs');
      final ids = (await tester.runAsync(h.db.songIds))!;
      await tester.runAsync(() => h.db.deleteTracksById([ids[1]]));

      await tester.tap(find.text('b'));
      await settleRows(tester);

      expect(find.text('That song is no longer in the library.'), findsOne);
      expect(h.container.read(playerServiceProvider).queue.original, isEmpty);
      expect(h.backend.calls.where((c) => c.startsWith('open(')), isEmpty);
      await release(tester, h);
    });

    testWidgets('a track removed before it plays from its real position', (
      tester,
    ) async {
      final h = harness();
      await openWithTracks(tester, h, const [
        TestTrack('a'),
        TestTrack('b'),
        TestTrack('c'),
      ], location: '/songs');
      final ids = (await tester.runAsync(h.db.songIds))!;
      // The tapped row moves from index 2 to 1 after this delete.
      await tester.runAsync(() => h.db.deleteTracksById([ids[0]]));

      await tester.tap(find.text('c'));
      await settleRows(tester);

      final queue = h.container.read(playerServiceProvider).queue;
      expect([for (final t in queue.original) t.title], ['b', 'c']);
      expect(queue.current?.title, 'c');
      expect(find.text('That song is no longer in the library.'), findsNothing);
      await release(tester, h);
    });
  });
}
