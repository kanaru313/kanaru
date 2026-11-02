import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_edit_writes.dart';
import 'package:kanaru/features/playlists/playlist_details.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart' show TestTrack, goTo, openWithTracks;
import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

void main() {
  late LibraryHarness h;
  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  Future<int> openPage(
    WidgetTester tester, {
    String? description,
    double width = 1280,
  }) async {
    await openWithTracks(tester, h, const [TestTrack('a')], location: '/home');
    final id = await seedPlaylist(tester, h, 'Mix', ['a']);
    if (description != null) {
      await tester.runAsync(
        () => h.db.updatePlaylistDetails(
          id,
          name: 'Mix',
          description: description,
        ),
      );
    }
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);
    return id;
  }

  final count = find.descendant(
    of: find.byType(PlaylistDetails),
    matching: find.text('1 song'),
  );
  final text = find.descendant(
    of: find.byType(PlaylistDetails),
    matching: find.byKey(const ValueKey('playlist-description-text')),
  );

  for (final (name, width) in [('side pane', 1280.0), ('header', 600.0)]) {
    testWidgets('the $name shows the description under the count', (
      tester,
    ) async {
      await openPage(tester, description: 'Songs for the road', width: width);

      expect(text, findsOneWidget);
      expect(tester.widget<Text>(text).data, 'Songs for the road');
      expect(
        tester.getTopLeft(text).dy,
        greaterThan(tester.getBottomLeft(count).dy),
      );
    });
  }

  testWidgets('an empty description draws nothing', (tester) async {
    await openPage(tester);

    expect(text, findsNothing);
  });

  testWidgets('a long description stops at three lines and scrolls', (
    tester,
  ) async {
    final long = List.generate(12, (i) => 'line $i').join('\n');
    await openPage(tester, description: long);

    final box = tester.getSize(
      find.descendant(
        of: find.byType(PlaylistDetails),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    final lineHeight = tester.getSize(text).height / 12;
    expect(box.height, closeTo(lineHeight * 3, 2));
    expect(find.byType(Scrollbar), findsNothing);
  });

  testWidgets('an edit shows in the page without a reload', (tester) async {
    final id = await openPage(tester, description: 'Old');

    await tester.runAsync(
      () => h.db.updatePlaylistDetails(
        id,
        name: 'Road trip',
        description: 'New text',
      ),
    );
    await settleDb(tester);

    expect(tester.widget<Text>(text).data, 'New text');
    expect(
      find.descendant(
        of: find.byType(PlaylistDetails),
        matching: find.text('Road trip'),
      ),
      findsOneWidget,
    );

    await tester.runAsync(
      () => h.db.updatePlaylistDetails(id, name: 'Road trip', description: ''),
    );
    await settleDb(tester);
    expect(text, findsNothing);
  });
}
