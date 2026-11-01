import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/artists/artist_header.dart';
import 'package:kanaru/shared/artist_modal/artist_more_button.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/artist_modal/artist_modal_test_support.dart';
import 'browse_test_data.dart';
import 'library_test_harness.dart';

const _songs = [
  TestTrack('One', artist: 'Ann', album: 'Al', track: 1),
  TestTrack('Two', artist: 'Ann', album: 'Al', track: 2),
];

void main() {
  for (final wide in [true, false]) {
    final layout = wide ? 'side pane' : 'header';
    final host = wide ? find.byType(ArtistSidePane) : find.byType(ArtistHeader);

    testWidgets('$layout: the more button opens the artist modal', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openWithTracks(tester, h, _songs, location: artistLocation('ann'));
      if (!wide) {
        tester.view.physicalSize = const Size(700, 800);
        await tester.pumpAndSettle();
      }
      expect(host, findsOneWidget);
      expect(find.byType(PopupMenuButton), findsNothing);
      expect(find.byType(QueueActionsButton), findsNothing);

      await tester.tap(
        find.descendant(of: host, matching: find.byType(ArtistMoreButton)),
      );
      await settleArtistModal(tester);

      expect(find.bySemanticsLabel('Artist options'), findsWidgets);
      expect(artistModalAction('play-all'), findsOneWidget);
      expect(artistModalAction('artist'), findsNothing);
    });
  }
}
