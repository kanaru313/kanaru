import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' show AlbumKey;
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_album_line.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/now_playing/now_playing_track_column.dart';
import 'package:kanaru/features/player/now_playing/now_playing_track_info.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import '../playlists/playlist_test_data.dart';

void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  /// Opens Now Playing at [size] on [track].
  Future<void> openNowPlaying(
    WidgetTester tester,
    Track track, {
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    await h.container.read(playerServiceProvider.notifier).openTracks([track]);
    await tester.pumpAndSettle();
    h.container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpAndSettle();
  }

  Finder inScreen(Finder f) =>
      find.descendant(of: find.byType(NowPlayingScreen), matching: f);

  /// The playing track's own text: the queue beside it in a wide window lists
  /// the same song.
  Finder inColumn(Finder f) =>
      find.descendant(of: find.byType(NowPlayingTrackColumn), matching: f);

  Future<Track> seededTrack(
    WidgetTester tester, {
    String? album = 'Blue Album',
  }) async {
    await openWithTracks(tester, h, [
      TestTrack('a', artist: 'Ann', album: album, albumArtist: 'Ann'),
    ], location: '/home');
    final paths = await trackPaths(tester, h);
    return Track(uri: paths['a']!, title: 'a', artist: 'Ann');
  }

  testWidgets('shows the album under the artist and opens its page on tap', (
    tester,
  ) async {
    final track = await seededTrack(tester);
    await openNowPlaying(tester, track);
    await tester.pumpAndSettle();

    final album = inColumn(find.text('Blue Album'));
    expect(album, findsOneWidget);
    expect(
      tester.getTopLeft(album).dy,
      greaterThan(tester.getTopLeft(inColumn(find.text('Ann'))).dy),
    );

    await tester.tap(album);
    await tester.pumpAndSettle();
    expect(h.container.read(nowPlayingOpenProvider), isFalse);
    expect(location(h), albumLocation(const AlbumKey('ann', 'blue album')));
    expect(find.text('Blue Album'), findsWidgets);
  });

  testWidgets('the narrow layout shows it too', (tester) async {
    final track = await seededTrack(tester);
    await openNowPlaying(tester, track, size: const Size(600, 700));

    expect(inScreen(find.text('Blue Album')), findsOneWidget);
    await tester.tap(inScreen(find.text('Blue Album')));
    await tester.pumpAndSettle();
    expect(h.container.read(nowPlayingOpenProvider), isFalse);
    expect(location(h), albumLocation(const AlbumKey('ann', 'blue album')));
  });

  testWidgets('a song without an album shows no album line', (tester) async {
    final track = await seededTrack(tester, album: null);
    await openNowPlaying(tester, track);

    expect(find.byType(NowPlayingAlbumLine), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NowPlayingAlbumLine),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });

  testWidgets('a file outside the library shows no album line', (tester) async {
    await seededTrack(tester);
    await openNowPlaying(
      tester,
      const Track(uri: '/elsewhere/x.mp3', title: 'x', artist: 'Ann'),
    );

    expect(
      find.descendant(
        of: find.byType(NowPlayingAlbumLine),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });

  /// The line alone, with no router above it, playing [paths] from the
  /// library of the harness.
  Future<ProviderContainer> pumpLineOnly(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryDatabaseProvider.overrideWithValue(h.db),
          audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: NowPlayingAlbumLine(centered: true)),
        ),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  Future<void> realWait(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('without a router the album is plain text', (tester) async {
    await openWithTracks(tester, h, [
      const TestTrack('a', album: 'Blue Album', albumArtist: 'Ann'),
    ], location: '/home');
    final paths = await trackPaths(tester, h);
    final container = await pumpLineOnly(tester);
    await container.read(playerServiceProvider.notifier).openTracks([
      Track(uri: paths['a']!, title: 'a'),
    ]);
    await realWait(tester);

    expect(find.text('Blue Album'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('an album tag without an album key is plain text, not a link', (
    tester,
  ) async {
    final track = await seededTrack(tester);
    await tester.runAsync(
      () => h.db.customStatement('UPDATE tracks SET album_title_key = NULL'),
    );
    await openNowPlaying(tester, track);

    final album = inColumn(find.text('Blue Album'));
    expect(album, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NowPlayingAlbumLine),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    final before = location(h);
    await tester.tap(album);
    await tester.pumpAndSettle();
    expect(h.container.read(nowPlayingOpenProvider), isTrue);
    expect(location(h), before);
  });

  testWidgets('the previous album stays while the next song is looked up', (
    tester,
  ) async {
    await openWithTracks(tester, h, [
      const TestTrack('a', album: 'Blue Album', albumArtist: 'Ann'),
      const TestTrack('b', album: 'Red Album', albumArtist: 'Ann'),
    ], location: '/home');
    final paths = await trackPaths(tester, h);
    final container = await pumpLineOnly(tester);
    final player = container.read(playerServiceProvider.notifier);
    await player.openTracks([
      Track(uri: paths['a']!, title: 'a'),
      Track(uri: paths['b']!, title: 'b'),
    ]);
    await realWait(tester);
    expect(find.text('Blue Album'), findsOneWidget);

    await player.next();
    // One frame, no real time: the database has not answered yet.
    await tester.pump();
    expect(find.text('Blue Album'), findsOneWidget);

    await realWait(tester);
    expect(find.text('Red Album'), findsOneWidget);
    expect(find.text('Blue Album'), findsNothing);
  });

  testWidgets('a failed lookup shows no album, not the previous one', (
    tester,
  ) async {
    await openWithTracks(tester, h, [
      const TestTrack('a', album: 'Blue Album', albumArtist: 'Ann'),
      const TestTrack('b', album: 'Red Album', albumArtist: 'Ann'),
    ], location: '/home');
    final paths = await trackPaths(tester, h);
    final container = await pumpLineOnly(tester);
    final player = container.read(playerServiceProvider.notifier);
    await player.openTracks([
      Track(uri: paths['a']!, title: 'a'),
      Track(uri: paths['b']!, title: 'b'),
    ]);
    await realWait(tester);
    expect(find.text('Blue Album'), findsOneWidget);

    await tester.runAsync(
      () => h.db.customStatement('ALTER TABLE tracks RENAME TO tracks_gone'),
    );
    await player.next();
    await realWait(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Blue Album'), findsNothing);
    expect(find.text('Red Album'), findsNothing);
  });

  for (final height in [480.0, 560.0]) {
    testWidgets('at $height px high the track column fits a two line title, '
        'the artist and the album without scrolling', (tester) async {
      await openWithTracks(tester, h, [
        const TestTrack('a', artist: 'Ann', album: 'Blue Album'),
      ], location: '/home');
      final paths = await trackPaths(tester, h);
      await openNowPlaying(
        tester,
        Track(
          uri: paths['a']!,
          title: List.filled(24, 'Long title').join(' '),
          artist: 'Ann',
        ),
        size: Size(1280, height),
      );

      // The page behind may overflow in a window this short; only the track
      // column counts (its own overflow is tested on its own).
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(NowPlayingTrackColumn),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      final column = tester.getRect(find.byType(NowPlayingTrackColumn));
      final album = tester.getRect(inColumn(find.text('Blue Album')));
      expect(album.bottom, lessThanOrEqualTo(column.bottom));
      expect(album.top, greaterThanOrEqualTo(column.top));
      // The controls under it fit too.
      expect(
        tester.getRect(inColumn(find.byTooltip('Pause'))).bottom,
        lessThanOrEqualTo(column.bottom),
      );
    });
  }

  /// [line] alone under a router, playing the seeded track `a`, with the
  /// router's location recorded in [at].
  Future<void> pumpLinked(
    WidgetTester tester,
    Widget line,
    List<String> at,
  ) async {
    final paths = await trackPaths(tester, h);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: Center(child: line)),
        ),
        GoRoute(
          path: '/:rest(.*)',
          builder: (_, state) {
            at.add(state.uri.toString());
            return const Scaffold();
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryDatabaseProvider.overrideWithValue(h.db),
          audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await container.read(playerServiceProvider.notifier).openTracks([
      Track(uri: paths['a']!, title: 'a', artist: 'Ann'),
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  void expectIconBesideText(WidgetTester tester, String text) {
    final icon = tester.getRect(find.byType(Icon));
    final label = tester.getRect(find.text(text));
    expect(icon.right + 8, closeTo(label.left, 0.5));
    expect(icon.center.dy, closeTo(label.center.dy, 1));
    expect(
      find.descendant(of: find.byType(InkWell), matching: find.byType(Icon)),
      findsNothing,
    );
  }

  testWidgets('the leading icon sits next to the album, outside the link', (
    tester,
  ) async {
    await seededTrack(tester);
    final at = <String>[];
    await pumpLinked(
      tester,
      const NowPlayingAlbumLine(centered: true, leadingIcon: AppIcons.album),
      at,
    );

    expect(find.byType(Icon), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);
    expectIconBesideText(tester, 'Blue Album');

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();
    expect(at, isEmpty);
  });

  testWidgets('a song without an album shows no icon', (tester) async {
    await seededTrack(tester, album: null);
    await pumpLinked(
      tester,
      const NowPlayingAlbumLine(centered: true, leadingIcon: AppIcons.album),
      <String>[],
    );

    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('tapping the icon does not navigate', (tester) async {
    await seededTrack(tester);
    final at = <String>[];
    await pumpLinked(
      tester,
      const NowPlayingAlbumLine(centered: true, leadingIcon: AppIcons.album),
      at,
    );

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();
    expect(at, isEmpty);
  });

  testWidgets('the title block shows artist and album icons with lineIcons', (
    tester,
  ) async {
    await seededTrack(tester);
    final paths = await trackPaths(tester, h);
    final track = Track(uri: paths['a']!, title: 'a', artist: 'Ann');
    await pumpLinked(
      tester,
      NowPlayingTitle(track: track, lineIcons: true),
      <String>[],
    );
    expect(find.byIcon(AppIcons.artist), findsOneWidget);
    expect(find.byIcon(AppIcons.album), findsOneWidget);
  });
}
