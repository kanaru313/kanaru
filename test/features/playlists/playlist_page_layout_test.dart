import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/cover_colors/cover_palette.dart';
import 'package:kanaru/core/cover_colors/cover_palette_of_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/playlists/playlist_details.dart';
import 'package:kanaru/features/playlists/playlist_header.dart';
import 'package:kanaru/features/playlists/playlist_side_pane.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/detail_page/collage_hero_cover.dart';
import 'package:kanaru/shared/widgets/detail_page/cover_tint_page_background.dart';
import 'package:kanaru/shared/widgets/detail_page/detail_side_pane.dart';
import 'package:kanaru/shared/widgets/detail_page/play_shuffle_actions.dart';
import 'package:kanaru/shared/widgets/detail_page/tracks_toolbar.dart';
import 'package:material_ui/material_ui.dart';

import '../library/browse_test_data.dart' show TestTrack, goTo, openWithTracks;
import '../library/library_test_harness.dart';
import 'playlist_entries_view_harness.dart';
import 'playlist_test_data.dart';

const _palette = CoverPalette(
  seed: Color(0xFFCC0000),
  colors: [Color(0xFFCC0000), Color(0xFF880000)],
);

// The side pane is too narrow for labels: Shuffle is an icon button there.
IconButton _shuffleButton(WidgetTester tester) => tester.widget<IconButton>(
  find.widgetWithIcon(IconButton, AppIcons.shuffle),
);

FilledButton _playButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.ancestor(
    of: find.text('Play'),
    matching: find.bySubtype<FilledButton>(),
  ),
);

void main() {
  /// Opens the app on a new playlist "Mix" of tracks titled [titles] (given
  /// covers when [withCovers]), plus [missing] entries with no file in the
  /// library, in a window [width] wide.
  Future<int> openPage(
    WidgetTester tester,
    LibraryHarness h, {
    List<String> titles = mixTitles,
    bool withCovers = false,
    int missing = 0,
    double width = 1280,
  }) async {
    await openWithTracks(tester, h, [
      for (final (i, t) in titles.indexed)
        TestTrack(t, coverKey: withCovers ? 'c$i' : null),
    ], location: '/home');
    final id = await seedPlaylist(
      tester,
      h,
      'Mix',
      titles,
      extraPaths: [for (var i = 0; i < missing; i++) '/gone/$i.mp3'],
    );
    tester.view.physicalSize = Size(width, 800);
    goTo(tester, h, '/playlists/$id');
    await settleDb(tester);
    return id;
  }

  group('layout', () {
    testWidgets('a wide window puts the playlist in a side pane', (
      tester,
    ) async {
      final h = LibraryHarness(refreshInterval: Duration.zero);
      await openPage(tester, h);

      final pane = find.byType(DetailSidePane);
      expect(find.byType(PlaylistSidePane), findsOneWidget);
      expect(pane, findsOneWidget);
      expect(find.byType(PlaylistHeader), findsNothing);
      expect(
        find.descendant(of: pane, matching: find.byType(CollageHeroCard)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pane, matching: find.byType(CollageHeroBackdrop)),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('Alpha')).dx,
        greaterThanOrEqualTo(tester.getTopRight(pane).dx),
      );
      expect(
        find.descendant(of: pane, matching: find.byType(PlayShuffleActions)),
        findsOneWidget,
      );
    });

    testWidgets('a narrow window keeps the header above the songs', (
      tester,
    ) async {
      final h = LibraryHarness(refreshInterval: Duration.zero);
      await openPage(tester, h, width: 700);

      expect(find.byType(DetailSidePane), findsNothing);
      expect(find.byType(PlaylistHeader), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Alpha')).dy,
        greaterThan(tester.getBottomLeft(find.byType(PlaylistHeader)).dy),
      );
    });

    testWidgets('the songs toolbar sits above the rows', (tester) async {
      final h = LibraryHarness(refreshInterval: Duration.zero);
      await openPage(tester, h);

      expect(find.byType(SliverTracksToolbar), findsOneWidget);
      expect(playlistSongCount('4 songs'), findsOneWidget);
    });

    testWidgets('an empty playlist has no toolbar', (tester) async {
      final view = EntriesViewHarness()..reset();
      await view.pump(tester, const []);

      expect(find.byType(SliverTracksToolbar), findsNothing);
      expect(find.byType(PlaylistSidePane), findsOneWidget);
    });

    testWidgets('Vietnamese at the side pane threshold does not overflow', (
      tester,
    ) async {
      final view = EntriesViewHarness()..reset();
      await view.pump(
        tester,
        [for (var i = 0; i < 5; i++) available(i)],
        width: 840,
        locale: const Locale('vi'),
        name: 'Danh sách phát dài',
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(PlaylistSidePane), findsOneWidget);
      expect(find.byTooltip('Phát ngẫu nhiên'), findsOneWidget);
    });
  });

  group('tint', () {
    Future<void> openTinted(WidgetTester tester, {required bool on}) async {
      final h = LibraryHarness(
        refreshInterval: Duration.zero,
        overrides: [
          initialSettingsProvider.overrideWithValue(
            AppSettings(display: DisplayPrefs(colorFromCover: on)),
          ),
          for (final key in ['c0', 'c1', 'c2', 'c3'])
            coverPaletteOfProvider(key).overrideWith((ref) async => _palette),
        ],
      );
      await openPage(tester, h, withCovers: true);
    }

    Finder gradient() => find.descendant(
      of: find.byType(CoverTintPageBackground),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient != null,
      ),
    );

    testWidgets('colors from the cover tint the page', (tester) async {
      await openTinted(tester, on: true);

      expect(
        tester
            .widget<CoverTintPageBackground>(
              find.byType(CoverTintPageBackground),
            )
            .coverKeys,
        unorderedEquals(['c0', 'c1', 'c2', 'c3']),
      );
      expect(gradient(), findsOneWidget);
    });

    testWidgets('with the setting off the page is not tinted', (tester) async {
      await openTinted(tester, on: false);

      expect(find.byType(CoverTintPageBackground), findsOneWidget);
      expect(gradient(), findsNothing);
    });
  });

  group('shuffle', () {
    testWidgets('queues the playable songs only', (tester) async {
      final h = LibraryHarness(refreshInterval: Duration.zero);
      await openPage(tester, h, missing: 2);
      expect(playlistSongCount('6 songs'), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.shuffle));
      await settleDb(tester);

      final queue = h.container.read(playerServiceProvider).queue;
      expect([
        for (final t in queue.original) t.title,
      ], unorderedEquals(mixTitles));
      expect(queue.original, hasLength(4));
    });

    testWidgets('waits for the write under way', (tester) async {
      final view = EntriesViewHarness()..reset();
      await view.pump(tester, [for (var i = 0; i < 3; i++) available(i)]);
      await view.dragHandle(tester, view.handle(0), 2 * rowExtent(tester));

      await tester.tap(find.byIcon(AppIcons.shuffle));
      await tester.pump();
      expect(view.shuffled, 0, reason: 'waits for the write');

      await view.finishMove(tester, ok: true);

      expect(view.shuffled, 1);
    });

    testWidgets('Play and Shuffle are disabled with nothing playable', (
      tester,
    ) async {
      final view = EntriesViewHarness()..reset();
      await view.pump(tester, [missing(1), missing(2)], onQueueAction: (_) {});

      expect(_playButton(tester).onPressed, isNull);
      expect(_shuffleButton(tester).onPressed, isNull);
      // Nothing to enqueue: the menu is left with Rename and Delete only.
      await tester.tap(find.byTooltip('Playlist actions'));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete playlist'), findsOneWidget);
      expect(find.text('Add to queue'), findsNothing);
      expect(find.byIcon(AppIcons.edit), findsOneWidget);
    });

    testWidgets('they are enabled when a song can play', (tester) async {
      final view = EntriesViewHarness()..reset();
      await view.pump(tester, [
        missing(1),
        available(2),
      ], onQueueAction: (_) {});

      expect(_shuffleButton(tester).onPressed, isNotNull);
      await tester.tap(find.byTooltip('Playlist actions'));
      await tester.pumpAndSettle();
      expect(find.text('Add to queue'), findsOneWidget);
    });
  });

  testWidgets('details show the name and the count once in the page', (
    tester,
  ) async {
    final view = EntriesViewHarness()..reset();
    await view.pump(tester, [available(1), available(2)], name: 'Road');

    expect(
      find.descendant(
        of: find.byType(PlaylistDetails),
        matching: find.text('Road'),
      ),
      findsOneWidget,
    );
    expect(playlistSongCount('2 songs'), findsOneWidget);
  });
}
