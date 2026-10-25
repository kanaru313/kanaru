import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_artist_line.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/library_route_keys.dart';
import 'package:kanaru/shared/widgets/hover_underline_links.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import '../library/browse_test_data.dart';
import '../library/library_test_harness.dart';
import '../playlists/playlist_test_data.dart';

FinderBase<TextRangeContext> _nameIn(String name) => find.textRange.ofSubstring(
  name,
  descendentOf: find.byType(NowPlayingArtistLine),
);

/// Global center of [name] in the artist line.
Offset _centerOf(WidgetTester tester, String name) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: find.byType(NowPlayingArtistLine),
      matching: find.byType(RichText),
    ),
  );
  final at = paragraph.text.toPlainText().indexOf(name);
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: at, extentOffset: at + name.length),
      )
      .first;
  return paragraph.localToGlobal(box.toRect().center);
}

/// The decoration of the span holding [name] in the artist line.
TextDecoration? _decorationOf(WidgetTester tester, String name) {
  final rich = tester.widget<RichText>(
    find.descendant(
      of: find.byType(NowPlayingArtistLine),
      matching: find.byType(RichText),
    ),
  );
  TextDecoration? found;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text == name) {
      found = span.style?.decoration;
    }
    return true;
  });
  return found;
}

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

  Finder inScreen(Finder f) =>
      find.descendant(of: find.byType(NowPlayingScreen), matching: f);

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

    final artist = inScreen(find.text('Ann'));
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

    await tester.tapOnText(_nameIn('Ann'));
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

    final artist = inScreen(find.text('Ann'));
    expect(artist, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NowPlayingArtistLine),
        matching: find.byType(HoverUnderlineLinks),
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
    expect(find.byType(HoverUnderlineLinks), findsNothing);
  });

  testWidgets('a separator between two artists is not a link', (tester) async {
    await openWithTracks(tester, h, [
      const TestTrack('a', artist: 'Ann; Bob'),
    ], location: '/home');
    final paths = await trackPaths(tester, h);
    await openNowPlaying(
      tester,
      Track(uri: paths['a']!, title: 'a', artist: 'Ann; Bob'),
    );

    expect(inScreen(find.byIcon(AppIcons.artistRounded)), findsNothing);
    final before = location(h);
    await tester.tapOnText(_nameIn('; '));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsNothing, reason: 'no picker');
    expect(location(h), before);
    expect(h.container.read(nowPlayingOpenProvider), isTrue);
  });

  testWidgets('hovering one of two artists underlines only that name', (
    tester,
  ) async {
    await openWithTracks(tester, h, [
      const TestTrack('a', artist: 'Ann; Bob'),
    ], location: '/home');
    final paths = await trackPaths(tester, h);
    await openNowPlaying(
      tester,
      Track(uri: paths['a']!, title: 'a', artist: 'Ann; Bob'),
    );

    expect(_decorationOf(tester, 'Ann'), isNull);
    expect(_decorationOf(tester, 'Bob'), isNull);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(_centerOf(tester, 'Bob'));
    await tester.pump();
    expect(_decorationOf(tester, 'Bob'), TextDecoration.underline);
    expect(_decorationOf(tester, 'Ann'), isNull);
    expect(_decorationOf(tester, '; '), isNull);
  });

  testWidgets('narrow layout: tapping the name navigates', (tester) async {
    await openWithTracks(tester, h, [
      const TestTrack('a', artist: 'Ann'),
    ], location: '/home');
    final paths = await trackPaths(tester, h);
    await openNowPlaying(
      tester,
      Track(uri: paths['a']!, title: 'a', artist: 'Ann'),
    );
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();

    await tester.tapOnText(_nameIn('Ann'));
    await tester.pumpAndSettle();
    expect(location(h), artistLocation('ann'));
  });

  testWidgets('keeps showing the current tag while old names are held', (
    tester,
  ) async {
    final artist = ValueNotifier('Ann; Bob');
    addTearDown(artist.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: artist,
              builder: (_, value, _) => NowPlayingArtistLine(artist: value),
            ),
          ),
        ),
        GoRoute(
          path: artistLocation('ann'),
          builder: (_, _) => const Scaffold(body: Text('ann page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Always the previous song's names, as while the next lookup runs.
          nowPlayingArtistsProvider.overrideWith(
            (ref) async => [
              (key: 'ann', name: 'Ann'),
              (key: 'bob', name: 'Bob'),
            ],
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textRange.ofSubstring('Ann'), findsOneWidget);
    expect(find.textRange.ofSubstring('Bob'), findsOneWidget);

    artist.value = 'Zed';
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      expect(find.text('Zed'), findsOneWidget);
      expect(find.textContaining('Ann'), findsNothing);
      expect(find.textContaining('Bob'), findsNothing);
    }

    // The whole tag links to the first name: with two names held, asks which.
    await tester.tapOnText(_nameIn('Zed'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Bob'), findsOneWidget);
    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    expect(find.text('ann page'), findsOneWidget);
  });
}
