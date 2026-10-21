import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/shared/widgets/album_list_tile.dart';
import 'package:kanaru/shared/widgets/artist_tile.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import 'search_test_data.dart';

/// The scrollable of the results, not of the navigation around it.
final _results = find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  testWidgets('groups matching songs, albums and artists', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'son tung');

    // The page titles also appear in the navigation, so look for the
    // section headers by their rich text.
    for (final header in ['Songs  2', 'Albums  1', 'Artists  1']) {
      expect(find.text(header, findRichText: true), findsOneWidget);
    }
    expect(find.text('Lạc Trôi'), findsOneWidget);
    expect(find.text('Chạy Ngay Đi'), findsOneWidget);
    expect(find.text('Sky Tour'), findsOneWidget);
    expect(find.text('Sơn Tùng M-TP'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);
  });

  testWidgets('hides sections without matches', (tester) async {
    final h = LibraryHarness();
    await openSearch(
      tester,
      h,
      'hello',
      tracks: const [TestTrack('Hello', artist: 'Zed', album: 'Other')],
    );

    expect(find.byType(SongTile), findsOneWidget);
    expect(find.byType(AlbumListTile), findsNothing);
    expect(find.byType(ArtistTile), findsNothing);
  });

  testWidgets('show all expands a section in place and a new query collapses '
      'it', (tester) async {
    final h = LibraryHarness();
    final tracks = [
      for (var i = 0; i < 12; i++) TestTrack('Song ${i + 10}', album: 'Mix'),
    ];
    await openSearch(tester, h, 'song', tracks: tracks);

    expect(find.text('Song 17'), findsOneWidget);
    expect(find.text('Song 18', skipOffstage: false), findsNothing);
    expect(find.text('Show all (12)'), findsOneWidget);

    await tester.tap(find.text('Show all (12)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Song 21'),
      200,
      scrollable: _results,
    );
    expect(find.text('Song 21'), findsOneWidget);
    expect(find.text('Show all (12)'), findsNothing);

    goTo(tester, h, '/search?q=song+1');
    await tester.pumpAndSettle();
    // "song 1" matches ten songs but starts collapsed.
    expect(find.text('Song 18', skipOffstage: false), findsNothing);
    expect(find.text('Show all (10)'), findsOneWidget);
  });

  testWidgets('many song matches show the narrow-down hint', (tester) async {
    final h = LibraryHarness();
    final tracks = [for (var i = 0; i < 201; i++) TestTrack('Song $i')];
    await openSearch(tester, h, 'song', tracks: tracks);

    await tester.tap(find.text('Show all (200)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Showing the first 200 of 201 songs'),
      2000,
      scrollable: _results,
    );
    expect(
      find.textContaining('Showing the first 200 of 201 songs'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a song plays only that song', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'son tung');

    await tester.tap(find.text('Chạy Ngay Đi'));
    await tester.pump();

    expect(queuedTitles(h), ['Chạy Ngay Đi']);
    expect(
      h.container.read(playerServiceProvider).queue.current?.uri,
      endsWith('.flac'),
    );
  });

  group('song result menu', () {
    testWidgets('song result menu adds the song to the queue', (tester) async {
      final h = LibraryHarness();
      await openSearch(tester, h, 'son tung');
      // Start a queue with another song first.
      goTo(tester, h, '/search?q=adele');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hello'));
      await tester.pump();
      expect(queuedTitles(h), ['Hello']);

      goTo(tester, h, '/search?q=son+tung');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lạc Trôi'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Play next'), findsOneWidget);
      await tester.tap(find.text('Add to queue'));
      await settleIo(tester, h);

      expect(queuedTitles(h), ['Hello', 'Lạc Trôi']);
      expect(find.text('Added to queue: Lạc Trôi'), findsOneWidget);
    });

    testWidgets('a long press opens the menu without playing', (tester) async {
      final h = LibraryHarness();
      await openSearch(tester, h, 'adele');

      await tester.longPress(find.text('Hello'));
      await tester.pumpAndSettle();
      expect(queuedTitles(h), isEmpty);
      await tester.tap(find.text('Play next'));
      await settleIo(tester, h);

      expect(queuedTitles(h), ['Hello']);
    });
  });

  testWidgets('tapping an album opens its page', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'son tung');

    await tester.tap(find.text('Sky Tour'));
    await tester.pumpAndSettle();

    expect(location(h), startsWith('/albums/'));
    expect(find.text('Sky Tour'), findsWidgets);
    expect(find.text('Lạc Trôi'), findsOneWidget);
  });

  testWidgets('tapping an artist opens their page', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'son tung');

    await tester.tap(find.text('Sơn Tùng M-TP'));
    await tester.pumpAndSettle();

    expect(location(h), startsWith('/artists/'));
  });

  testWidgets('back from an album returns to the same results', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'son tung');
    await tester.tap(find.text('Sky Tour'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(location(h), '/search?q=son+tung');
    expect(find.text('Songs'), findsOneWidget);
    expect(find.text('Lạc Trôi'), findsOneWidget);
  });

  testWidgets('results follow a rescan', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'adele');
    expect(find.text('Rolling'), findsNothing);

    await insertTracks(tester, h, const [
      TestTrack('Rolling', artist: 'Adele', album: '21'),
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rolling'), findsOneWidget);
  });
}
