import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/queue/queue_button.dart';
import 'package:kanaru/features/player/queue/queue_play_next_marker.dart';
import 'package:kanaru/features/player/queue/queue_tile.dart';
import 'package:kanaru/shared/widgets/favorite_button.dart';
import 'package:kanaru/shared/widgets/song_card.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';
import '../library/library_test_harness.dart';
import '../playlists/playlist_test_data.dart';

List<Track> named(int count, {String prefix = 't'}) => [
  for (var i = 0; i < count; i++)
    Track(uri: '/music/$prefix$i.mp3', title: '$prefix$i', artist: 'artist $i'),
];

/// A widget test on the desktop platform: the test default (Android) pads icon
/// buttons to 48 px, which is not the look the rows are sized for.
void rowTest(String name, Future<void> Function(WidgetTester tester) body) =>
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  List<String> titles() => [
    for (final t in container.read(playerServiceProvider).queue.tracks) t.title,
  ];

  Future<void> pumpApp(
    WidgetTester tester,
    List<Track> tracks, {
    int start = 0,
    double textScale = 1,
    Locale locale = const Locale('en'),
    bool openSheet = true,
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
        child: KanaruApp(locale: locale),
      ),
    );
    await tester.pumpAndSettle();
    await player().openTracks(tracks, start: start);
    backend.calls.clear();
    await tester.pumpAndSettle();
    if (openSheet) {
      await tester.tap(find.byType(QueueButton));
      await tester.pumpAndSettle();
    }
  }

  double scrollPixels(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ReorderableListView),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position
      .pixels;

  Finder tile(int row) => find.byType(QueueTile).at(row);
  QueueTile tileWidget(WidgetTester tester, int row) =>
      tester.widget<QueueTile>(tile(row));

  double extentOf(WidgetTester tester, double clampTo) => songCardExtent(
    Theme.of(tester.element(tile(0))),
    TextScaler.linear(clampTo),
  );

  Finder moreButton(int row) =>
      find.descendant(of: tile(row), matching: find.byTooltip('More options'));

  /// Tabs until the focus is inside the row at [row].
  Future<void> focusRow(WidgetTester tester, int row) async {
    for (var i = 0; i < 60; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final tile = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<QueueTile>();
      if (tile?.position == row) return;
    }
    fail('Tab never reached row $row');
  }

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

  Finder handle(int row) => find.descendant(
    of: tile(row),
    matching: find.byIcon(Icons.drag_handle_rounded),
  );

  group('layout', () {
    rowTest('shows three lines with "album • year"', (tester) async {
      await pumpApp(tester, const [
        Track(
          uri: '/m/a.mp3',
          title: 'Song',
          artist: 'Band',
          album: 'Record',
          year: 2001,
        ),
        Track(uri: '/m/b.mp3', title: 'Plain', artist: 'Solo'),
      ]);

      expect(find.text('Record • 2001'), findsOneWidget);
      expect(find.textContaining('•'), findsOneWidget);
      // Both rows have the same height, so a missing third line leaves it
      // empty.
      expect(tester.getSize(tile(0)).height, tester.getSize(tile(1)).height);
      expect(tester.getSize(tile(0)).height, extentOf(tester, 1));
    });

    rowTest('text scale 2 is capped at 1.25 and the lines fit the row', (
      tester,
    ) async {
      {
        await pumpApp(tester, [
          const Track(
            uri: '/m/a.mp3',
            title: 'A very long title that cannot fit on one line at all',
            artist: 'An equally long artist name for this row',
            album: 'Album with a long name too',
            year: 1999,
            duration: Duration(minutes: 3, seconds: 5),
          ),
          ...named(2),
        ], textScale: 2);

        expect(tester.takeException(), isNull);
        final extent = extentOf(tester, 1.25);
        expect(tester.getSize(tile(0)).height, extent);
        // The three lines, measured as laid out, plus the row's 16 px of
        // padding fit the row: nothing is clipped.
        final title = tester.getRect(
          find.descendant(of: tile(0), matching: find.textContaining('A very')),
        );
        final detail = tester.getRect(
          find.descendant(
            of: tile(0),
            matching: find.text('Album with a long name too • 1999'),
          ),
        );
        expect(detail.bottom - title.top + 16, lessThanOrEqualTo(extent));
        expect(
          detail.bottom,
          lessThanOrEqualTo(tester.getRect(tile(0)).bottom),
        );
      }
    });

    rowTest('fits in Vietnamese without overflow', (tester) async {
      await pumpApp(tester, [
        const Track(
          uri: '/m/a.mp3',
          title: 'Một bài hát có tên rất dài không thể vừa trong một dòng',
          artist: 'Nghệ sĩ có tên dài không kém',
          album: 'Album',
          year: 2001,
          duration: Duration(minutes: 3),
        ),
        ...named(2),
      ], locale: const Locale('vi'));

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Kéo để sắp xếp lại'), findsWidgets);
      expect(tester.getSize(tile(0)).height, extentOf(tester, 1));
    });

    rowTest('50 000 tracks build fewer than 50 tiles and open at the '
        'playing row in the first frame', (tester) async {
      await pumpApp(
        tester,
        named(50000),
        start: 500,
        textScale: 1.25,
        openSheet: false,
      );

      await tester.tap(find.byType(QueueButton));
      await tester.pump();

      expect(find.byType(QueueTile).evaluate().length, lessThan(50));
      expect(scrollPixels(tester), 499 * extentOf(tester, 1.25));
    });

    rowTest('a text scale change keeps the first row in place', (tester) async {
      await pumpApp(tester, named(2000), start: 500);
      final before = extentOf(tester, 1);
      expect(scrollPixels(tester), 499 * before);

      tester.platformDispatcher.textScaleFactorTestValue = 1.25;
      await tester.pump();

      final after = extentOf(tester, 1.25);
      expect(after, isNot(before));
      expect(scrollPixels(tester), 499 * after);
    });
  });

  group('highlight', () {
    rowTest('a file queued twice lights only the row at the index', (
      tester,
    ) async {
      final a = named(1).first;
      await pumpApp(tester, [a, ...named(3, prefix: 'u'), a], start: 4);

      final current = [
        for (var i = 0; i < 5; i++) tileWidget(tester, i).current,
      ];
      expect(current, [false, false, false, false, true]);
    });
  });

  group('play next marker', () {
    rowTest('marks only the run rows and hints "Play next"', (tester) async {
      final handle = tester.ensureSemantics();
      // Tall enough to build all eight rows.
      await pumpApp(tester, named(6), start: 1, size: const Size(1280, 1000));
      await player().playNext(named(2, prefix: 'n'));
      await tester.pumpAndSettle();

      expect(titles(), ['t0', 't1', 'n0', 'n1', 't2', 't3', 't4', 't5']);
      final marked = [for (var i = 0; i < 8; i++) tileWidget(tester, i).upNext];
      expect(marked, [false, false, true, true, false, false, false, false]);
      expect(
        find.descendant(
          of: tile(2),
          matching: find.byType(QueuePlayNextMarker),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile(4),
          matching: find.byType(QueuePlayNextMarker),
        ),
        findsNothing,
      );
      expect(
        tester.getSemantics(find.text('n0')).getSemanticsData().hint,
        contains('Play next'),
      );
      handle.dispose();
    });

    rowTest('no stray marks after Previous and none on played rows', (
      tester,
    ) async {
      await pumpApp(tester, named(5), start: 1);
      await player().playNext(named(1, prefix: 'n'));
      await player().jump(0);
      await tester.pumpAndSettle();

      // t0 is playing; n0 is no longer right behind it, so it is not a run.
      expect(titles().indexOf('n0'), 2);
      final marked = [for (var i = 0; i < 6; i++) tileWidget(tester, i).upNext];
      expect(marked, [false, false, false, false, false, false]);
    });
  });

  group('remove', () {
    rowTest('the more button is always visible and opens the menu', (
      tester,
    ) async {
      await pumpApp(tester, named(3));
      expect(moreButton(1), findsOneWidget);

      await tester.tap(moreButton(1));
      await tester.pumpAndSettle();
      expect(find.text('Remove from queue'), findsOneWidget);

      await tester.tap(find.text('Remove from queue'));
      await tester.pumpAndSettle();
      expect(titles(), ['t0', 't2']);
    });

    rowTest('Enter on the focused more button opens the menu', (tester) async {
      await pumpApp(tester, named(3));
      await focusRow(tester, 1);

      var reached = false;
      for (var i = 0; i < 12 && !reached; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final context = FocusManager.instance.primaryFocus?.context;
        reached =
            context?.findAncestorWidgetOfExactType<IconButton>()?.tooltip ==
            'More options';
      }
      expect(reached, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Remove from queue'), findsOneWidget);
    });

    rowTest('a screen reader can remove through a custom action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, named(3));

      final node = tester.getSemantics(
        find.descendant(of: tile(1), matching: find.text('t1')),
      );
      final nodeId = node.id;
      final data = node.getSemanticsData();
      final ids = data.customSemanticsActionIds ?? const <int>[];
      final id = ids.firstWhere(
        (id) =>
            CustomSemanticsAction.getAction(id)?.label == 'Remove from queue',
      );
      tester.semantics.performAction(
        find.semantics.byPredicate((node) => node.id == nodeId),
        SemanticsAction.customAction,
        args: id,
      );
      await tester.pumpAndSettle();

      expect(titles(), ['t0', 't2']);
      handle.dispose();
    });
  });

  group('keyboard and tap', () {
    rowTest('Shift+F10 on the playing row opens its menu', (tester) async {
      await pumpApp(tester, named(3));

      await focusRow(tester, 0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(find.text('Remove from queue'), findsOneWidget);
    });

    rowTest('the playing row takes focus', (tester) async {
      await pumpApp(tester, named(3));

      await focusRow(tester, 0);

      expect(
        FocusManager.instance.primaryFocus!.context!
            .findAncestorWidgetOfExactType<QueueTile>()!
            .current,
        isTrue,
      );
    });
  });

  group('drag', () {
    rowTest('the playing row has a handle and drags without a reopen', (
      tester,
    ) async {
      await pumpApp(tester, named(4));
      expect(handle(0), findsOneWidget);
      final extent = tester.getSize(tile(0)).height;

      await dragHandle(tester, handle(0), 2 * extent);

      expect(titles(), ['t1', 't2', 't0', 't3']);
      expect(backend.calls.where((c) => c.startsWith('open')), isEmpty);
      expect(container.read(playerServiceProvider).queue.index, 2);
    });

    rowTest('the dragged row lifts as the card, not its slot', (tester) async {
      await pumpApp(tester, named(4));
      final slot = tester.getRect(tile(0));

      final gesture = await tester.startGesture(tester.getCenter(handle(0)));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump(const Duration(milliseconds: 16));

      final plate = find.byElementPredicate(
        (e) =>
            e.widget is DecoratedBox &&
            (e.widget as DecoratedBox).decoration is BoxDecoration &&
            ((e.widget as DecoratedBox).decoration as BoxDecoration)
                    .boxShadow !=
                null,
      );
      expect(plate, findsOneWidget);
      final size = tester.getSize(plate);
      expect(size.width, slot.width - 2 * songCardInset);
      expect(size.height, slot.height - songCardGap);
      expect(
        ((tester.widget<DecoratedBox>(plate)).decoration as BoxDecoration)
            .borderRadius,
        BorderRadius.circular(songCardRadius),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    rowTest('a tap on the handle does not jump', (tester) async {
      await pumpApp(tester, named(4));

      await tester.tap(handle(2));
      await tester.pumpAndSettle();

      expect(container.read(playerServiceProvider).queue.index, 0);
      expect(backend.calls, isEmpty);
    });

    rowTest('a row moved mid-drag still moves the right entry', (tester) async {
      await pumpApp(tester, named(8));
      final extent = tester.getSize(tile(0)).height;

      final gesture = await tester.startGesture(tester.getCenter(handle(4)));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(Offset(0, extent * 0.6));
      await tester.pump(const Duration(milliseconds: 16));
      // t1 moves behind t4 while t4 is held: t4 is now at index 3, and the
      // index the list reports (4) is t5.
      await player().moveTrack(1, 5);
      await tester.pump();
      // Flutter's reorderable list asserts about a duplicate global key when
      // rows change under a held row; that is its own known limit and not
      // what is checked here.
      expect(tester.takeException(), isA<FlutterError>());
      await gesture.moveBy(Offset(0, extent * 1.2));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();
      tester.takeException();

      // Dropping at the stale index would have moved t5 instead of t4: the
      // others keep their order and t4 left its place.
      final order = titles();
      expect([...order]..remove('t4'), [
        't0',
        't2',
        't3',
        't5',
        't1',
        't6',
        't7',
      ]);
      expect(order.indexOf('t4'), greaterThan(3));
    });

    rowTest('a queue replaced mid-drag ignores the drop', (tester) async {
      await pumpApp(tester, named(5), start: 4);
      final extent = tester.getSize(tile(0)).height;

      final gesture = await tester.startGesture(tester.getCenter(handle(1)));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(Offset(0, extent * 0.6));
      await tester.pump(const Duration(milliseconds: 16));
      await player().openTracks(named(5, prefix: 'z'), start: 4);
      await tester.pump();
      await gesture.moveBy(Offset(0, extent * 1.2));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(titles(), ['z0', 'z1', 'z2', 'z3', 'z4']);
    });
  });

  group('heart', () {
    late LibraryHarness h;
    setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

    Future<void> openQueue(WidgetTester tester, List<Track> q) async {
      await h.container.read(playerServiceProvider.notifier).openTracks(q);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show now playing list'));
      await settleDb(tester);
      await tester.pumpAndSettle();
    }

    IconButton heart(WidgetTester tester, int row) => tester.widget<IconButton>(
      find.descendant(
        of: find.descendant(
          of: find.byType(QueueTile).at(row),
          matching: find.byType(FavoriteButton),
        ),
        matching: find.byType(IconButton),
      ),
    );

    rowTest('is off for an outside file and on for a library file or a '
        'favorite', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openApp(tester, h, ['a']);
      final p = await trackPaths(tester, h);
      await openQueue(tester, [
        Track(uri: p['a']!, title: 'a'),
        const Track(uri: '/elsewhere/x.mp3', title: 'x'),
      ]);

      expect(heart(tester, 0).onPressed, isNotNull);
      expect(heart(tester, 1).onPressed, isNull);

      // A favorite that left the library can still be taken out.
      await tester.runAsync(
        () => h.db.setFavorite('/elsewhere/x.mp3', favorite: true, now: 1),
      );
      await settleDb(tester);
      await tester.pumpAndSettle();
      expect(heart(tester, 1).onPressed, isNotNull);
    });
  });
}
