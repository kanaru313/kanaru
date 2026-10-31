import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/songs/songs_list_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/library/browse_test_data.dart';
import '../../features/library/library_test_harness.dart';
import '../song_modal/song_modal_test_support.dart';

const _tracks = [TestTrack('a'), TestTrack('b'), TestTrack('c')];

void main() {
  List<String> queue(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.tracks)
      t.title,
  ];

  group('song modal opening', () {
    testWidgets(
      'a right click opens the song modal, not a popup at the pointer',
      (tester) async {
        final h = LibraryHarness();
        await openWithTracks(tester, h, _tracks, location: '/songs');

        await openSongModal(tester, find.text('b'));

        expect(find.text('Go to artist'), findsOneWidget);
        expect(find.byType(PopupMenuItem<Object?>), findsNothing);
        // A centered dialog, not anchored at the pointer.
        final window = tester.getSize(find.byType(MaterialApp).first);
        expect(
          tester.getCenter(modalAction('artist')).dx,
          closeTo(window.width / 2, window.width / 4),
        );
      },
    );

    testWidgets('a long press opens the song modal', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/songs');

      await tester.longPress(find.text('b'));
      await settleSongModal(tester);

      expect(find.text('Go to artist'), findsOneWidget);
      expect(find.byType(PopupMenuItem<Object?>), findsNothing);
    });
  });

  group('rows shown while the ids load', () {
    // The ids never arrive: only the first page of rows is on screen.
    LibraryHarness harness() => LibraryHarness(
      overrides: [songIdsProvider.overrideWith((ref) => const Stream.empty())],
    );

    testWidgets('a right click opens the menu and queues the song', (
      tester,
    ) async {
      final h = harness();
      await openWithTracks(tester, h, _tracks, location: '/songs');
      expect(find.text('b'), findsOneWidget);

      await tester.tap(find.text('b'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to queue'));
      await settleIo(tester, h);

      expect(queue(h), ['b']);
      expect(find.text('Playing: b'), findsOneWidget);
    });

    testWidgets('a long press opens the menu without playing the row', (
      tester,
    ) async {
      final h = harness();
      await openWithTracks(tester, h, _tracks, location: '/songs');

      await tester.longPress(find.text('b'));
      await tester.pumpAndSettle();

      expect(find.text('Play next'), findsOneWidget);
      expect(queue(h), isEmpty, reason: 'a long press is not a tap');
      expect(h.backend.calls.where((c) => c.startsWith('open(')), isEmpty);
    });
  });
}
