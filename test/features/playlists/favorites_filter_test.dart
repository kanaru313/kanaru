import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

const _tracks = [
  TestTrack('Blue Sky', artist: 'Ann'),
  TestTrack('Sky High', artist: 'Bob'),
  TestTrack('Night', artist: 'Skyler'),
  TestTrack('Day', artist: 'Cy'),
];

void main() {
  testWidgets('Favorites filters its liked songs and plays the matches', (
    tester,
  ) async {
    final h = LibraryHarness(refreshInterval: Duration.zero);
    await openWithTracks(tester, h, _tracks, location: '/favorites');
    final paths = await trackPaths(tester, h);
    for (final title in ['Blue Sky', 'Day', 'Night', 'Sky High']) {
      await tester.runAsync(
        () => h.db.setFavorite(paths[title]!, favorite: true, now: 1),
      );
    }
    await settleDb(tester);
    expect(shownTitles(tester), hasLength(4));

    await tester.tap(find.byTooltip('Filter in this page'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(InPageSearchBox),
        matching: find.byType(TextField),
      ),
      'sky',
    );
    await tester.pump(const Duration(milliseconds: 150));
    await settleDb(tester);

    // Title starts with it, then title has it, then artist has it.
    expect(shownTitles(tester), ['Sky High', 'Blue Sky', 'Night']);
    expect(find.byTooltip('Remove from playlist'), findsNothing);

    await tester.tap(find.text('Blue Sky'));
    await tester.pump();

    final queue = h.container.read(playerServiceProvider).queue;
    expect(
      [for (final t in queue.original) t.title],
      ['Sky High', 'Blue Sky', 'Night'],
    );
    expect(queue.current?.title, 'Blue Sky');
  });
}
