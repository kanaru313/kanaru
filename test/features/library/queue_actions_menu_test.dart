import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/library/songs/songs_list_provider.dart';
import 'package:kanaru/features/library/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _tracks = [TestTrack('a'), TestTrack('b'), TestTrack('c')];

void main() {
  List<String> queue(LibraryHarness h) => [
    for (final t in h.container.read(playerServiceProvider).queue.tracks)
      t.title,
  ];

  /// Where the first entry of the open menu starts.
  Offset menuCorner(WidgetTester tester) => tester.getTopLeft(
    find.ancestor(
      of: find.text('Play next'),
      matching: find.byType(PopupMenuItem<QueueAction>, skipOffstage: false),
    ),
  );

  group('menu position', () {
    testWidgets('opens at the pointer on the wide layout with the sidebar', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/songs');
      final pointer = tester.getCenter(find.text('b'));
      // The page is inside the shell, not at the window's corner.
      expect(pointer.dx, greaterThan(200));

      await tester.tap(find.text('b'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      final corner = menuCorner(tester);
      expect((corner.dx - pointer.dx).abs(), lessThan(2));
      // The menu's own padding sits above its first entry.
      expect(corner.dy - pointer.dy, inInclusiveRange(0, 16));
    });

    testWidgets('opens at the pointer on a long press', (tester) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _tracks, location: '/songs');
      final pointer = tester.getCenter(find.text('b'));

      await tester.longPress(find.text('b'));
      await tester.pumpAndSettle();

      final corner = menuCorner(tester);
      expect((corner.dx - pointer.dx).abs(), lessThan(2));
      expect(corner.dy - pointer.dy, inInclusiveRange(0, 16));
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
