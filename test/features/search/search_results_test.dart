import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/search/search_prefs_provider.dart';
import 'package:kanaru/shared/widgets/album_list_tile.dart';
import 'package:kanaru/shared/widgets/artist_tile.dart';
import 'package:kanaru/shared/widgets/song_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/fake_tag_reader.dart';
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

/// The album result row's title; song rows show the album name too.
Finder _albumRow(String title) =>
    find.descendant(of: find.byType(AlbumListTile), matching: find.text(title));

/// The artist result row's name; song and album rows show it too.
Finder _artistRow(String name) =>
    find.descendant(of: find.byType(ArtistTile), matching: find.text(name));

/// A song result row's title, not a Home card behind the search page.
Finder _resultSong(String title) => find.descendant(
  of: find.byType(SongTile),
  matching: find.text(title, skipOffstage: false),
);

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
    expect(_albumRow('Sky Tour'), findsOneWidget);
    expect(_artistRow('Sơn Tùng M-TP'), findsOneWidget);
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
    expect(_resultSong('Song 18'), findsNothing);
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
    await tester.scrollUntilVisible(
      find.text('Show less'),
      200,
      scrollable: _results,
    );
    expect(find.text('Show less'), findsOneWidget);

    // The toggle keeps the same button, so keyboard focus stays on it.
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(_resultSong('Song 21'), findsNothing);
    expect(find.text('Show all (12)'), findsOneWidget);
    await tester.tap(find.text('Show all (12)'));
    await tester.pumpAndSettle();

    goTo(tester, h, '/search?q=song+1');
    await tester.pumpAndSettle();
    // "song 1" matches ten songs but starts collapsed.
    expect(_resultSong('Song 18'), findsNothing);
    expect(find.text('Show all (10)'), findsOneWidget);
  });

  testWidgets('many song matches say they show the top ones and hint', (
    tester,
  ) async {
    final h = LibraryHarness();
    final tracks = [for (var i = 0; i < 1201; i++) TestTrack('Song $i')];
    await openSearch(tester, h, 'song', tracks: tracks);

    expect(find.text('Songs  1,201', findRichText: true), findsOneWidget);
    expect(find.text('Show all (200)'), findsNothing);
    await tester.tap(find.text('Show top 200'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Showing the top 200 of 1,201 songs'),
      2000,
      scrollable: _results,
    );
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('tapping a song plays only that song with its cover', (
    tester,
  ) async {
    final h = LibraryHarness(coverCacheDirectory: '/covers');
    final key = fakeCoverKey('red');
    await openSearch(
      tester,
      h,
      'son tung',
      tracks: [
        TestTrack('Lạc Trôi', artist: 'Sơn Tùng M-TP', coverKey: key),
        const TestTrack('Chạy Ngay Đi', artist: 'Sơn Tùng M-TP'),
      ],
    );

    await tester.tap(find.text('Lạc Trôi'));
    await tester.pump();

    expect(queuedTitles(h), ['Lạc Trôi']);
    final current = h.container.read(playerServiceProvider).queue.current;
    expect(current?.uri, matches(RegExp(r'^/m/\d+/0\.flac$')));
    expect(current?.artUri, '/covers/$key');
  });

  group('song result menu', () {
    testWidgets('adds the song to the queue', (tester) async {
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

    await tester.tap(_albumRow('Sky Tour'));
    await tester.pumpAndSettle();

    expect(location(h), startsWith('/albums/'));
    expect(find.text('Sky Tour'), findsWidgets);
    expect(find.text('Lạc Trôi'), findsOneWidget);
  });

  testWidgets('tapping an artist opens their page', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'son tung');

    await tester.tap(_artistRow('Sơn Tùng M-TP'));
    await tester.pumpAndSettle();

    expect(location(h), startsWith('/artists/'));
  });

  testWidgets('back from an album returns to the same results', (tester) async {
    final h = LibraryHarness();
    await openSearch(tester, h, 'son tung');
    await tester.tap(_albumRow('Sky Tour'));
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
    // Wait for the reload itself, not for a fixed time.
    for (var i = 0; i < 200 && find.text('Rolling').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    expect(find.text('Rolling'), findsOneWidget);
  });

  testWidgets('a narrow window lays the results out without overflow', (
    tester,
  ) async {
    final h = LibraryHarness();
    final tracks = [
      for (var i = 0; i < 12; i++)
        TestTrack(
          'A very long song title that cannot fit a narrow window $i',
          artist: 'Sơn Tùng M-TP with a very long artist credit',
          album: 'Sky Tour with a very long album name',
          albumArtist: 'Sơn Tùng M-TP with a very long artist credit',
        ),
    ];
    await insertTracks(tester, h, tracks);
    await h.pump(tester, hasRoots: true);
    tester.view.physicalSize = const Size(480, 800);
    goTo(tester, h, '/search?q=son+tung');
    await tester.pumpAndSettle();

    expect(find.byType(SongTile), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Show all (12)'),
      200,
      scrollable: _results,
    );
    await tester.drag(_results, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show all (12)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(AlbumListTile),
      300,
      scrollable: _results,
    );
    expect(find.byType(AlbumListTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows Vietnamese strings', (tester) async {
    final h = LibraryHarness();
    final tracks = [for (var i = 0; i < 12; i++) TestTrack('Song ${i + 10}')];
    await insertTracks(tester, h, tracks);
    await h.pump(tester, hasRoots: true);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: const KanaruApp(locale: Locale('vi')),
      ),
    );
    goTo(tester, h, '/search?q=song');
    await tester.pumpAndSettle();

    expect(find.text('Xem tất cả (12)'), findsOneWidget);
    await tester.tap(find.text('Xem tất cả (12)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Thu gọn'),
      200,
      scrollable: _results,
    );
    expect(find.text('Thu gọn'), findsOneWidget);

    goTo(tester, h, '/search?q=zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Không có kết quả'), findsOneWidget);
    expect(
      find.textContaining('Không tìm thấy kết quả cho “zzzz”'),
      findsOneWidget,
    );
  });

  group('search history', () {
    List<String> history(LibraryHarness h) =>
        h.container.read(searchPrefsProvider).value!.history;

    testWidgets('playing a result remembers the query as typed', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openSearch(tester, h, 'artist:"son tung"');
      expect(history(h), isEmpty);

      await tester.tap(find.text('Lạc Trôi'));
      await tester.pump();

      expect(history(h), ['artist:"son tung"']);
    });

    testWidgets('typing different queries remembers nothing', (tester) async {
      final h = LibraryHarness();
      await openSearch(tester, h, 'son');
      goTo(tester, h, '/search?q=son+t');
      await tester.pumpAndSettle();
      goTo(tester, h, '/search?q=son+tung');
      await tester.pumpAndSettle();

      expect(history(h), isEmpty);
    });

    testWidgets('the queue menu of a song remembers the query', (tester) async {
      final h = LibraryHarness();
      await openSearch(tester, h, 'son tung');

      await tester.tap(find.text('Lạc Trôi'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to queue'));
      await tester.pumpAndSettle();

      expect(history(h), ['son tung']);
    });

    testWidgets('opening an album or an artist remembers the query', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openSearch(tester, h, 'son tung');
      await tester.tap(find.byType(AlbumListTile));
      await tester.pumpAndSettle();
      expect(history(h), ['son tung']);

      goTo(tester, h, '/search?q=adele');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ArtistTile));
      await tester.pumpAndSettle();
      expect(history(h), ['adele', 'son tung']);
    });
  });
}
