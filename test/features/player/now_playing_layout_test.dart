import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/shell/window/desktop_window.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/repeat_mode.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_header.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/now_playing/now_playing_seek_slot.dart';
import 'package:kanaru/features/player/now_playing/now_playing_track_column.dart';
import 'package:kanaru/features/player/queue/queue_button.dart';
import 'package:kanaru/features/player/repeat/repeat_button.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/features/player/track_artwork.dart';
import 'package:kanaru/features/player/seek_bar.dart';
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

  Future<void> pumpOpen(
    WidgetTester tester,
    Size size, {
    bool customTitleBar = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Reduced motion: page changes and the slide complete in one frame.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        customTitleBarProvider.overrideWithValue(customTitleBar),
      ],
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

  Finder inColumn(Finder finder) =>
      find.descendant(of: find.byType(NowPlayingTrackColumn), matching: finder);

  /// The cover of the playing track; the queue's rows have covers too.
  final cover = find.descendant(
    of: find.byType(NowPlayingTrackColumn),
    matching: find.byType(TrackArtwork),
  );

  group('wide', () {
    testWidgets('lays out the cover, title and artist in the first column', (
      tester,
    ) async {
      await pumpOpen(tester, const Size(1280, 800));

      final column = tester.getRect(find.byType(NowPlayingTrackColumn));
      final art = tester.getRect(cover);
      expect(art.center.dx, closeTo(column.center.dx, 1));
      expect(art.width, lessThanOrEqualTo(500));
      expect(art.width, art.height);
      expect(inColumn(find.text('First Song')), findsOneWidget);
      expect(inColumn(find.text('Some Artist')), findsOneWidget);
      expect(inColumn(find.byIcon(AppIcons.artist)), findsOneWidget);
      final title = tester.getRect(inColumn(find.text('First Song')));
      expect(title.center.dx, closeTo(column.center.dx, 1));
      expect(title.top, greaterThan(art.bottom));
    });

    testWidgets('keeps a big window cover to 500 px', (tester) async {
      await pumpOpen(tester, const Size(2560, 1440));

      expect(tester.getSize(cover), const Size(500, 500));
    });

    testWidgets('has no footer: the header holds the actions', (tester) async {
      await pumpOpen(tester, const Size(1280, 800));
      final header = tester.getRect(find.byType(NowPlayingHeader));
      expect(header.height, 64);
      expect(header.top, 0);

      // The queue rows have hearts too: look in the header for that one.
      Rect at(String tooltip) => tester.getRect(
        tooltip == 'Add to favorites'
            ? find.descendant(
                of: find.byType(NowPlayingHeader),
                matching: find.byTooltip(tooltip),
              )
            : inScreen(find.byTooltip(tooltip)),
      );
      for (final tooltip in [
        'Close Now Playing',
        'Add to favorites',
        'Add to playlist',
        'Shuffle',
        'Stop after the last song',
        'Sleep timer',
        'Mute',
      ]) {
        expect(at(tooltip).bottom, lessThanOrEqualTo(header.bottom));
      }
      expect(at('Close Now Playing').center.dx, lessThan(header.center.dx));
      expect(at('Shuffle').center.dx, greaterThan(header.center.dx));
      // The controls moved to the track column, under the cover.
      final column = tester.getRect(find.byType(NowPlayingTrackColumn));
      expect(at('Pause').center.dx, closeTo(column.center.dx, 1));
      expect(at('Pause').top, greaterThan(header.bottom));
      expect(at('Previous').center.dx, lessThan(at('Pause').center.dx));
      expect(at('Next').center.dx, greaterThan(at('Pause').center.dx));
      // Shuffle and repeat are not among them.
      expect(at('Shuffle').top, lessThan(header.bottom));
      // The seek track is over the buttons, the times beside them.
      final times = tester.getRect(inScreen(find.text('0:00')).first);
      expect(times.center.dy, closeTo(at('Pause').center.dy, 2));
      expect(
        tester.getRect(inScreen(find.byType(NowPlayingSeekSlot))).bottom,
        lessThan(at('Pause').top + 4),
      );
    });

    testWidgets('has no queue button', (tester) async {
      await pumpOpen(tester, const Size(1280, 800));

      expect(inScreen(find.byTooltip('Show now playing list')), findsNothing);
      expect(inScreen(find.byType(QueueButton)), findsNothing);
    });

    testWidgets('shuffle and repeat buttons change the player', (tester) async {
      await pumpOpen(tester, const Size(1280, 800));

      await tester.tap(inScreen(find.byTooltip('Shuffle')));
      await tester.pump();
      expect(container.read(playerServiceProvider).queue.shuffled, isTrue);

      await tester.tap(inScreen(find.byType(RepeatButton)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repeat the whole queue'));
      await tester.pumpAndSettle();
      expect(
        container.read(playerServiceProvider).queue.repeat,
        RepeatMode.all,
      );
    });

    testWidgets('has the favorite heart, off without a library', (
      tester,
    ) async {
      await pumpOpen(tester, const Size(1280, 800));

      // The header's heart; the queue rows have their own.
      final heart = find.descendant(
        of: find.byType(NowPlayingHeader),
        matching: find.byTooltip('Add to favorites'),
      );
      expect(heart, findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(of: heart, matching: find.byType(IconButton)),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('closes from the header', (tester) async {
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
      expect(inScreen(find.byTooltip('Show now playing list')), findsOneWidget);
    });

    testWidgets('has no volume button and no bottom buttons row', (
      tester,
    ) async {
      await pumpOpen(tester, const Size(600, 700));

      expect(inScreen(find.byTooltip('Mute')), findsNothing);
      expect(inScreen(find.byIcon(Icons.volume_up_rounded)), findsNothing);
      // Close and queue are in the header, close together at the left.
      final close = tester.getRect(
        inScreen(find.byTooltip('Close Now Playing')),
      );
      final queue = tester.getRect(
        inScreen(find.byTooltip('Show now playing list')),
      );
      expect(close.top, lessThan(64));
      expect(queue.top, lessThan(64));
      expect(close.left, lessThan(queue.left));
      expect(queue.left - close.right, lessThan(16));
      expect(queue.right, lessThan(150));
    });

    testWidgets('centers the dots on the whole window', (tester) async {
      for (final width in [600.0, 480.0]) {
        await pumpOpen(tester, Size(width, 700));
        final queue = tester.getRect(inScreen(find.byTooltip('Now playing')));
        final track = tester.getRect(inScreen(find.byTooltip('Song')));
        final dots = queue.expandToInclude(track);
        expect(dots.center.dx, closeTo(width / 2, 1));
        expect(dots.top, lessThan(64));
        // Unmounting schedules the disposal of providers Now Playing
        // watched; let it run before the next app replaces this one.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });

    testWidgets('keeps the dots centered beside the window buttons', (
      tester,
    ) async {
      await pumpOpen(tester, const Size(480, 360), customTitleBar: true);

      final queue = tester.getRect(inScreen(find.byTooltip('Now playing')));
      final track = tester.getRect(inScreen(find.byTooltip('Song')));
      expect(queue.expandToInclude(track).center.dx, closeTo(240, 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the header queue button opens the queue page', (tester) async {
      await pumpOpen(tester, const Size(600, 700));

      await tester.tap(inScreen(find.byTooltip('Show now playing list')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<PageView>(inScreen(find.byType(PageView)))
            .controller!
            .page,
        0,
      );
      // On the queue page the queue button turns into a way back.
      expect(inScreen(find.byTooltip('Show now playing list')), findsNothing);
      await tester.tap(inScreen(find.byTooltip('Back to the song')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PageView>(inScreen(find.byType(PageView)))
            .controller!
            .page,
        1,
      );
      expect(inScreen(find.byTooltip('Show now playing list')), findsOneWidget);
    });

    testWidgets('keeps the playing page on the bottom edge', (tester) async {
      await pumpOpen(tester, const Size(600, 900));

      final play = tester.getRect(inScreen(find.byTooltip('Pause')));
      expect(play.bottom, greaterThan(900 - 48));
    });

    testWidgets('puts the cover alone in the middle, the rest at the bottom', (
      tester,
    ) async {
      await pumpOpen(tester, const Size(480, 900));

      final cover = tester.getRect(inScreen(find.byType(TrackArtwork)));
      final title = tester.getRect(inScreen(find.text('First Song')));
      final seek = tester.getRect(inScreen(find.byType(SeekBar)));
      final play = tester.getRect(inScreen(find.byTooltip('Pause')));
      // Footer order: title, seek bar, then the buttons on the bottom edge.
      expect(title.bottom, lessThan(seek.top));
      expect(seek.bottom, lessThanOrEqualTo(play.top));
      expect(play.bottom, greaterThan(900 - 48));
      // The cover in the middle of the room between header and footer.
      expect(cover.center.dy, closeTo((64 + title.top) / 2, 24));
      // Buttons spread over the row, play/pause a 60 circle in the middle.
      expect(play.size, const Size.square(60));
      expect(play.center.dx, closeTo(240, 1));
      final shuffle = tester.getRect(inScreen(find.byTooltip('Shuffle')));
      final repeat = tester.getRect(
        inScreen(find.byTooltip('Stop after the last song')),
      );
      expect(repeat.right - shuffle.left, greaterThan(360));
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

      await tester.tap(inScreen(find.byTooltip('Now playing')));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(pages).controller!.page, 0);

      await tester.tap(inScreen(find.byTooltip('Song')));
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(pages).controller!.page, 1);
    });

    testWidgets('with reduced motion a dot switches the page in one frame', (
      tester,
    ) async {
      await pumpOpen(tester, const Size(600, 700));
      final pages = inScreen(find.byType(PageView));

      await tester.tap(inScreen(find.byTooltip('Now playing')));
      await tester.pump();

      expect(tester.widget<PageView>(pages).controller!.page, 0);
      expect(tester.hasRunningAnimations, isFalse);
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
