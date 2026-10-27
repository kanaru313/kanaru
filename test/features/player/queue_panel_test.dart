import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/app/shell/navigation_history.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:kanaru/features/player/now_playing/now_playing_screen.dart';
import 'package:kanaru/features/player/player_bar.dart';
import 'package:kanaru/features/player/queue/queue_panel.dart';
import 'package:kanaru/features/player/queue/queue_tile.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/song_card.dart';
import 'package:kanaru/shared/widgets/song_row_view.dart';
import 'package:kanaru/shared/widgets/song_tile_cover.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

List<Track> named(int count) => [
  for (var i = 0; i < count; i++)
    Track(uri: '/music/t$i.mp3', title: 't$i', artist: 'artist $i'),
];

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  List<String> titles() => [
    for (final t in container.read(playerServiceProvider).queue.tracks) t.title,
  ];
  Track? current() => container.read(playerServiceProvider).queue.current;

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    int count = 4,
    int start = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await player().openTracks(named(count), start: start);
    backend.calls.clear();
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Show now playing list'));
    await tester.pumpAndSettle();
  }

  Finder handle(int row) => find.descendant(
    of: find.byType(QueueTile).at(row),
    matching: find.byIcon(Icons.drag_handle_rounded),
  );

  Finder remove(int row) => find.descendant(
    of: find.byType(QueueTile).at(row),
    matching: find.byTooltip('Remove from queue'),
  );

  /// Height of a queue row.
  double rowExtent(WidgetTester tester) =>
      tester.getSize(find.byType(QueueTile).first).height;

  /// Puts the mouse over a row, which reveals its remove button.
  Future<TestGesture> hoverRow(WidgetTester tester, int row) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(QueueTile).at(row)));
    await tester.pump();
    return mouse;
  }

  /// Hovers a row and presses its remove button.
  Future<void> removeRow(WidgetTester tester, int row) async {
    await hoverRow(tester, row);
    await tester.tap(remove(row));
    await tester.pumpAndSettle();
  }

  /// Drags a row's handle by [dy] in small steps, as a hand would, so the
  /// list sees every row it passes.
  Future<void> dragHandle(WidgetTester tester, Finder handle, double dy) async {
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    final step = dy.sign * 8;
    for (var moved = 0.0; moved.abs() < dy.abs(); moved += step) {
      await gesture.moveBy(Offset(0, step));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('sheet', () {
    testWidgets('opens from the player bar with a title and count', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.byType(QueuePanel), findsNothing);

      await openSheet(tester);

      expect(find.byType(QueuePanel), findsOneWidget);
      expect(find.text('Now playing'), findsOneWidget);
      expect(find.text('4 tracks'), findsOneWidget);
      expect(find.byType(QueueTile), findsNWidgets(4));
      expect(tester.getSize(find.byType(QueuePanel)).width, 440);
      // The remove icon is filled and hidden until a row is hovered or
      // focused.
      expect(find.byIcon(Icons.delete_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(of: remove(0), matching: find.byType(IgnorePointer))
                  .first,
            )
            .ignoring,
        isTrue,
      );
      // Clear and save sit in the header's overflow menu; the header has no
      // jump-to-current button (the floating one appears only when needed).
      expect(find.byTooltip('Clear queue'), findsNothing);
      expect(find.byTooltip('More actions'), findsOneWidget);
      expect(find.byTooltip('Jump to current song'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('counts one track in the singular', (tester) async {
      await pumpApp(tester, count: 1);
      await openSheet(tester);

      expect(find.text('1 track'), findsOneWidget);
    });

    testWidgets('tapping outside closes it', (tester) async {
      await pumpApp(tester);
      await openSheet(tester);

      await tester.tapAt(const Offset(100, 300));
      await tester.pumpAndSettle();

      expect(find.byType(QueuePanel), findsNothing);
    });

    testWidgets('the close button closes it', (tester) async {
      await pumpApp(tester);
      await openSheet(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(QueuePanel),
          matching: find.byTooltip('Close now playing list'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QueuePanel), findsNothing);
    });

    testWidgets('Esc closes the shell sheet', (tester) async {
      await pumpApp(tester);
      await openSheet(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(QueuePanel), findsNothing);
    });

    testWidgets('focus moves into the sheet and leaves it on close', (
      tester,
    ) async {
      bool inSheet() {
        final focus = FocusManager.instance.primaryFocus;
        if (focus == null) return false;
        return [
          focus,
          ...focus.ancestors,
        ].any((n) => n.debugLabel == 'Queue sheet');
      }

      await pumpApp(tester);
      expect(inSheet(), isFalse);

      await openSheet(tester);
      expect(inSheet(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(inSheet(), isFalse);
    });

    Future<void> pressMouseBack(WidgetTester tester) async {
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kBackMouseButton,
      );
      await mouse.down(const Offset(100, 300));
      await mouse.up();
      await tester.pumpAndSettle();
    }

    testWidgets('the mouse back button closes the shell sheet only', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();
      await openSheet(tester);

      await pressMouseBack(tester);
      expect(find.byType(QueuePanel), findsNothing);
      // The page was not left: back went to the sheet, not the history.
      expect(find.text('Artists'), findsWidgets);
      expect(container.read(navigationHistoryProvider).canGoForward, isFalse);
    });

    testWidgets('the mouse back button closes Now Playing', (tester) async {
      await pumpApp(tester);
      container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsOneWidget);

      await pressMouseBack(tester);
      expect(find.byType(NowPlayingScreen), findsNothing);
    });

    testWidgets('wide Now Playing has the queue in a tab, no sheet button', (
      tester,
    ) async {
      await pumpApp(tester);
      container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pumpAndSettle();

      final inScreen = find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.byType(QueuePanel),
      );
      expect(inScreen, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NowPlayingScreen),
          matching: find.byTooltip('Show now playing list'),
        ),
        findsNothing,
      );

      // Esc closes Now Playing; nothing sheet-like is in the way.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsNothing);
    });

    testWidgets('the narrow Now Playing queue button switches to the page', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(600, 700));
      container.read(nowPlayingOpenProvider.notifier).open();
      await tester.pumpAndSettle();
      final pages = find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.byType(PageView),
      );
      expect(find.byType(QueuePanel), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(NowPlayingScreen),
          matching: find.byTooltip('Show now playing list'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<PageView>(pages).controller!.page, 0);
      expect(find.byType(QueuePanel), findsOneWidget);
      expect(find.byType(QueueTile), findsNWidgets(4));
    });

    testWidgets('closes itself when the queue is emptied', (tester) async {
      await pumpApp(tester, count: 1);
      await openSheet(tester);

      await removeRow(tester, 0);

      expect(find.byType(QueuePanel), findsNothing);
    });
  });

  group('rows', () {
    testWidgets('mark the playing track and dim the played ones', (
      tester,
    ) async {
      await pumpApp(tester, start: 2);
      await openSheet(tester);

      Opacity opacity(int row) => tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(QueueTile).at(row),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity(0).opacity, 0.6);
      expect(opacity(1).opacity, 0.6);
      expect(opacity(2).opacity, 1);
      expect(
        find.descendant(
          of: find.byType(QueueTile).at(2),
          matching: find.byIcon(Icons.graphic_eq_rounded),
        ),
        findsOneWidget,
      );
      // No position numbers; the playing row has the equalizer on its cover
      // and the playing colors, the others have the plain card colour.
      Color? fill(int row) => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.descendant(
                    of: find.byType(QueueTile).at(row),
                    matching: find.byType(SongRowView),
                  ),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;
      final scheme = Theme.of(tester.element(find.byType(QueueTile).at(2)))
          .colorScheme;
      expect(fill(2), scheme.primaryContainer);
      expect(fill(3), songCardColor(scheme));
      expect(
        find.descendant(
          of: find.byType(QueueTile).at(3),
          matching: find.byIcon(Icons.graphic_eq_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('the playing row keeps its look while paused', (tester) async {
      await pumpApp(tester, start: 1);
      expect(container.read(playerServiceProvider).playing, isTrue);
      await player().pause();
      expect(container.read(playerServiceProvider).playing, isFalse);
      await tester.pumpAndSettle();
      await openSheet(tester);

      final row = find.byType(QueueTile).at(1);
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(Icons.graphic_eq_rounded),
        ),
        findsOneWidget,
      );
      // The cover shows the equalizer instead of its music note.
      expect(
        find.descendant(
          of: find.descendant(of: row, matching: find.byType(SongTileCover)),
          matching: find.byIcon(Icons.music_note_rounded),
        ),
        findsNothing,
      );
      final scheme = Theme.of(tester.element(row)).colorScheme;
      final card = tester.widget<Material>(
        find
            .descendant(
              of: find.descendant(of: row, matching: find.byType(SongRowView)),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.color, scheme.primaryContainer);
    });

    testWidgets('tapping the playing row does nothing', (tester) async {
      await pumpApp(tester);
      await openSheet(tester);
      final playing = current()!.title;

      await tester.tap(
        find.descendant(
          of: find.byType(QueuePanel),
          matching: find.text(playing),
        ),
      );
      await tester.pumpAndSettle();

      expect(current()!.title, playing);
      expect(backend.calls, isEmpty);
      expect(find.byType(QueuePanel), findsOneWidget);
    });

    testWidgets('tapping a row plays it and keeps the panel open', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSheet(tester);

      await tester.tap(find.text('t2'));
      await tester.pumpAndSettle();

      expect(current()!.title, 't2');
      expect(backend.calls, ['open(t2, next: t3)']);
      expect(find.byType(QueuePanel), findsOneWidget);
    });

    testWidgets('follow the shuffled order', (tester) async {
      // Tall enough to build all eight rows.
      await pumpApp(tester, count: 8, start: 3, size: const Size(1280, 1000));
      await player().setShuffle(true);
      await openSheet(tester);

      final shown = [
        for (final tile in tester.widgetList<QueueTile>(find.byType(QueueTile)))
          tile.track.title,
      ];
      expect(shown, titles());
      expect(shown.first, 't3');
    });
  });

  group('editing', () {
    testWidgets('dragging a row down reorders without interrupting', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSheet(tester);

      await dragHandle(tester, handle(0), 2 * rowExtent(tester));

      expect(titles(), ['t1', 't2', 't0', 't3']);
      expect(current()!.title, 't0');
      expect(container.read(playerServiceProvider).queue.index, 2);
      expect(backend.calls, ['setNext(t3)']);
    });

    testWidgets('dragging a row up reorders without interrupting', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSheet(tester);

      await dragHandle(tester, handle(3), -2 * rowExtent(tester));

      expect(titles(), ['t0', 't3', 't1', 't2']);
      expect(current()!.title, 't0');
      expect(backend.calls.where((c) => c.startsWith('open')), isEmpty);
      expect(backend.calls, ['setNext(t3)']);
    });

    testWidgets('removing another row requeues the next track', (tester) async {
      await pumpApp(tester);
      await openSheet(tester);

      await removeRow(tester, 1);

      expect(titles(), ['t0', 't2', 't3']);
      expect(find.text('3 tracks'), findsOneWidget);
      expect(backend.calls, ['setNext(t2)']);
    });

    testWidgets('removing the playing row plays the next one', (tester) async {
      await pumpApp(tester);
      await openSheet(tester);

      await removeRow(tester, 0);

      expect(titles(), ['t1', 't2', 't3']);
      expect(current()!.title, 't1');
      expect(backend.calls, ['open(t1, next: t2)']);
    });

    testWidgets('clearing keeps the playing track playing', (tester) async {
      await pumpApp(tester, start: 1);
      await openSheet(tester);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear queue'));
      await tester.pumpAndSettle();

      expect(titles(), ['t1']);
      expect(current()!.title, 't1');
      expect(container.read(playerServiceProvider).playing, isTrue);
      expect(backend.calls, ['setNext(null)']);
      // Nothing else to clear.
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MenuItemButton>(
              find.widgetWithText(MenuItemButton, 'Clear queue'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('the queue button badge follows the count', (tester) async {
      await pumpApp(tester);
      expect(find.text('4'), findsOneWidget);

      await player().removeTrack(3);
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('the badge is not in the error colour', (tester) async {
      await pumpApp(tester);

      final badge = tester.widget<Badge>(find.byType(Badge));
      final scheme = Theme.of(tester.element(find.byType(Badge))).colorScheme;
      expect(badge.backgroundColor, scheme.secondaryContainer);
      expect(badge.textColor, scheme.onSecondaryContainer);
    });

    testWidgets('the queue button closes the open sheet', (tester) async {
      await pumpApp(tester);
      await openSheet(tester);
      expect(find.byTooltip('Show now playing list'), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(PlayerBar),
          matching: find.byTooltip('Close now playing list'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QueuePanel), findsNothing);
      expect(find.byTooltip('Show now playing list'), findsOneWidget);
    });
  });

  group('long queues', () {
    testWidgets('build only the rows on screen and open at the playing track', (
      tester,
    ) async {
      await pumpApp(tester, count: 10000, start: 5000);
      await openSheet(tester);

      expect(find.byType(QueueTile).evaluate().length, lessThan(50));
      // The playing track is the second row.
      final tiles = tester.widgetList<QueueTile>(find.byType(QueueTile));
      expect(tiles.elementAt(1).track.title, 't5000');
      expect(tiles.elementAt(1).current, isTrue);
      expect(tiles.first.track.title, 't4999');
    });

    testWidgets('"Now playing" scrolls back to the playing track', (
      tester,
    ) async {
      await pumpApp(tester, count: 200);
      await openSheet(tester);
      await tester.drag(
        find.byType(ReorderableListView),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      Finder row(String title) => find.descendant(
        of: find.byType(ReorderableListView),
        matching: find.text(title),
      );
      expect(row('t0'), findsNothing);

      await tester.tap(find.byTooltip('Jump to current song'));
      await tester.pumpAndSettle();

      expect(row('t0'), findsOneWidget);
    });
  });

  group('title slot', () {
    Future<void> pumpPanel(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      backend = FakeAudioBackend();
      container = ProviderContainer(
        overrides: [audioBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: QueuePanel(title: Text('custom tabs'))),
          ),
        ),
      );
      await player().openTracks(named(3));
      await tester.pumpAndSettle();
    }

    testWidgets('replaces the title only, keeps the summary and buttons', (
      tester,
    ) async {
      await pumpPanel(tester);

      expect(find.text('custom tabs'), findsOneWidget);
      expect(find.text('Now playing'), findsNothing);
      expect(find.text('3 tracks'), findsOneWidget);
    });

    testWidgets('the filter button opens the box and Esc returns focus', (
      tester,
    ) async {
      await pumpPanel(tester);

      await tester.tap(find.byTooltip('Filter in this page'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, AppIcons.search),
      );
      expect(button.focusNode?.hasFocus, isTrue);
    });
  });
}
