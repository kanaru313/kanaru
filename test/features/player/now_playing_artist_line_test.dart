import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_artist_line.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_track_column.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/library_route_keys.dart';
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

  /// Opens Now Playing on [track].
  Future<void> openNowPlaying(WidgetTester tester, Track track) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(1280, 800);
    await h.container.read(playerServiceProvider.notifier).openTracks([track]);
    await tester.pumpAndSettle();
    h.container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpAndSettle();
  }

  /// The playing track's own text: the queue beside it lists the same song.
  Finder inColumn(Finder f) =>
      find.descendant(of: find.byType(NowPlayingTrackColumn), matching: f);

  testWidgets('a song with one artist opens the artist page on tap', (
    tester,
  ) async {
    await openWithTracks(tester, h, [
      const TestTrack('a', artist: 'Ann'),
    ], location: '/home');
    final paths = await trackPaths(tester, h);
    await openNowPlaying(
      tester,
      Track(uri: paths['a']!, title: 'a', artist: 'Ann'),
    );

    final artist = inColumn(find.text('Ann'));
    expect(artist, findsOneWidget);
    await tester.tap(artist);
    await tester.pumpAndSettle();

    expect(h.container.read(nowPlayingOpenProvider), isFalse);
    expect(location(h), artistLocation('ann'));
  });

  testWidgets('a song with two artists asks which on tap', (tester) async {
    await openWithTracks(tester, h, [
      const TestTrack('a', artist: 'Ann; Bob'),
    ], location: '/home');
    final paths = await trackPaths(tester, h);
    await openNowPlaying(
      tester,
      Track(uri: paths['a']!, title: 'a', artist: 'Ann; Bob'),
    );

    await tester.tap(inColumn(find.text('Ann; Bob')));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
    expect(
      h.container.read(nowPlayingOpenProvider),
      isTrue,
      reason: 'nothing chosen yet',
    );

    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    expect(h.container.read(nowPlayingOpenProvider), isFalse);
    expect(location(h), artistLocation('bob'));
  });

  testWidgets('a file outside the library shows the artist as plain text', (
    tester,
  ) async {
    await openWithTracks(tester, h, [
      const TestTrack('a', artist: 'Ann'),
    ], location: '/home');
    await openNowPlaying(
      tester,
      const Track(uri: '/elsewhere/x.mp3', title: 'x', artist: 'Ann'),
    );

    final artist = inColumn(find.text('Ann'));
    expect(artist, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NowPlayingArtistLine),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    final before = location(h);
    await tester.tap(artist);
    await tester.pumpAndSettle();
    expect(location(h), before);
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
          home: const Scaffold(body: NowPlayingArtistLine(artist: 'Ann')),
        ),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  testWidgets('without a router the artist is plain text', (tester) async {
    await openWithTracks(tester, h, [
      const TestTrack('a', artist: 'Ann'),
    ], location: '/home');
    final paths = await trackPaths(tester, h);
    final container = await pumpLineOnly(tester);
    await container.read(playerServiceProvider.notifier).openTracks([
      Track(uri: paths['a']!, title: 'a'),
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ann'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

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

  testWidgets('the leading icon sits next to the artist, outside the link', (
    tester,
  ) async {
    await openWithTracks(tester, h, [
      const TestTrack('a', artist: 'Ann'),
    ], location: '/home');
    final at = <String>[];
    await pumpLinked(
      tester,
      const NowPlayingArtistLine(artist: 'Ann', leadingIcon: AppIcons.artist),
      at,
    );

    expect(find.byType(Icon), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);
    expectIconBesideText(tester, 'Ann');

    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();
    expect(at, isEmpty);
  });
}
