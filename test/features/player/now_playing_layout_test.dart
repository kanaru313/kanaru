import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_footer.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/track_artwork.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;

import '../../core/player/fake_audio_backend.dart';

final songs = [
  const Track(
    uri: '/music/First Song.flac',
    title: 'First Song',
    artist: 'Some Artist',
  ),
  Track.fromPath('/music/Second Song.mp3'),
];

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  final screen = find.byType(NowPlayingScreen);

  Future<void> pumpOpen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The seek bar's wave never settles while music plays.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KanaruApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
    await player().openTracks(songs);
    await tester.pumpAndSettle();
    // The page behind may overflow in a tiny window; only Now Playing counts.
    tester.takeException();
    container.read(nowPlayingOpenProvider.notifier).open();
    await tester.pumpAndSettle();
  }

  Finder inScreen(Finder finder) =>
      find.descendant(of: screen, matching: finder);

  group('wide', () {
    testWidgets('centers the cover, title and artist', (tester) async {
      await pumpOpen(tester, const Size(1280, 800));

      final art = tester.getRect(inScreen(find.byType(TrackArtwork)));
      expect(art.center.dx, closeTo(640, 1));
      // At most half the window height.
      expect(art.width, 400);
      expect(art.height, 400);
      expect(inScreen(find.text('First Song')), findsOneWidget);
      expect(inScreen(find.text('Some Artist')), findsOneWidget);
      expect(inScreen(find.byIcon(Icons.person_rounded)), findsOneWidget);
      final title = tester.getRect(inScreen(find.text('First Song')));
      expect(title.center.dx, closeTo(640, 1));
      expect(title.top, greaterThan(art.bottom));
    });

    testWidgets('keeps a big window cover to half the height', (tester) async {
      await pumpOpen(tester, const Size(1920, 1080));

      expect(
        tester.getSize(inScreen(find.byType(TrackArtwork))),
        const Size(540, 540),
      );
    });

    testWidgets('has the three footer groups', (tester) async {
      await pumpOpen(tester, const Size(1280, 800));
      final footer = tester.getRect(find.byType(NowPlayingFooter));
      expect(footer.height, 80);
      expect(footer.bottom, 800);

      Rect at(String tooltip) =>
          tester.getRect(inScreen(find.byTooltip(tooltip)));
      expect(at('Close Now Playing').center.dx, lessThan(footer.center.dx));
      expect(at('Add to favorites').center.dx, lessThan(footer.center.dx));
      expect(at('Add to playlist').center.dx, lessThan(footer.center.dx));
      expect(at('Pause').center.dx, closeTo(640, 1));
      expect(at('Shuffle').center.dx, lessThan(640));
      expect(at('Next').center.dx, greaterThan(640));
      expect(at('Mute').center.dx, greaterThan(footer.center.dx));
      expect(at('Open queue').center.dx, greaterThan(at('Mute').center.dx));
      // The seek bar is under the buttons.
      expect(
        tester.getRect(inScreen(find.text('0:00')).first).center.dy,
        greaterThan(at('Pause').bottom - 8),
      );
    });

    testWidgets('the queue button counts the tracks', (tester) async {
      await pumpOpen(tester, const Size(1280, 800));
      expect(inScreen(find.text('2')), findsOneWidget);

      await player().removeTrack(1);
      await tester.pumpAndSettle();
      expect(inScreen(find.text('1')), findsOneWidget);
    });

    testWidgets('shuffle and repeat buttons change the player', (tester) async {
      await pumpOpen(tester, const Size(1280, 800));

      await tester.tap(inScreen(find.byTooltip('Shuffle')));
      await tester.pump();
      expect(container.read(playerServiceProvider).queue.shuffled, isTrue);

      await tester.tap(inScreen(find.byTooltip('Repeat off')));
      await tester.pump();
      expect(
        container.read(playerServiceProvider).queue.repeat,
        RepeatMode.all,
      );
    });

    testWidgets('favorite and playlist only say they are coming', (
      tester,
    ) async {
      await pumpOpen(tester, const Size(1280, 800));

      await tester.tap(inScreen(find.byTooltip('Add to favorites')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(inScreen(find.text('Coming soon')), findsOneWidget);
    });

    testWidgets('closes from the footer', (tester) async {
      await pumpOpen(tester, const Size(1280, 800));

      await tester.tap(inScreen(find.byTooltip('Close Now Playing')));
      await tester.pumpAndSettle();

      expect(screen, findsNothing);
    });
  });

  group('narrow', () {
    testWidgets('starts on the playing page', (tester) async {
      await pumpOpen(tester, const Size(600, 700));

      final controller = tester
          .widget<PageView>(inScreen(find.byType(PageView)))
          .controller;
      expect(controller!.page, 1);
      expect(inScreen(find.text('First Song')), findsOneWidget);
      // Cover: at most 45% of the height.
      expect(tester.getSize(inScreen(find.byType(TrackArtwork))).width, 315);
      expect(inScreen(find.byTooltip('Pause')), findsOneWidget);
      expect(inScreen(find.byTooltip('Add to favorites')), findsOneWidget);
      expect(inScreen(find.byTooltip('Open queue')), findsOneWidget);
    });

    testWidgets('swiping reveals the queue page', (tester) async {
      await pumpOpen(tester, const Size(600, 700));
      final pages = inScreen(find.byType(PageView));

      await tester.drag(pages, const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(pages).controller!.page, 0);

      await tester.drag(pages, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(pages).controller!.page, 1);
    });

    testWidgets('the dots switch pages', (tester) async {
      await pumpOpen(tester, const Size(600, 700));
      final pages = inScreen(find.byType(PageView));

      await tester.tap(inScreen(find.byTooltip('Queue')));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(pages).controller!.page, 0);

      await tester.tap(inScreen(find.byTooltip('Now Playing')));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(pages).controller!.page, 1);
    });

    testWidgets('closes from the page', (tester) async {
      await pumpOpen(tester, const Size(600, 700));

      await tester.tap(inScreen(find.byTooltip('Close Now Playing')));
      await tester.pumpAndSettle();

      expect(screen, findsNothing);
    });
  });

  group('sizes', () {
    for (final size in const [
      Size(480, 360),
      Size(720, 500),
      Size(719, 500),
      Size(1920, 1080),
    ]) {
      testWidgets('fit $size without overflowing', (tester) async {
        await pumpOpen(tester, size);

        expect(screen, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a long title wraps to two lines and an artist shows', (
      tester,
    ) async {
      await pumpOpen(tester, const Size(720, 500));
      await player().openTracks([
        Track(
          uri: '/music/long.mp3',
          title: 'A very long title ' * 12,
          artist: 'Artist ' * 20,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
