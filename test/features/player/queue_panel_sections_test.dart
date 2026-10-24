import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/queue/queue_panel.dart';
import 'package:kanaru/features/player/queue/queue_now_playing_tile.dart';
import 'package:kanaru/features/player/queue/queue_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

List<Track> named(int count, {String prefix = 't'}) => [
  for (var i = 0; i < count; i++)
    Track(uri: '/music/$prefix$i.mp3', title: '$prefix$i'),
];

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  List<String> titles() => [
    for (final t in container.read(playerServiceProvider).queue.tracks) t.title,
  ];
  int run() => player().upNextRun;

  /// Opens the app with [count] tracks, [start] playing and [playNext] extra
  /// tracks (`p0`...) queued to play next, then the queue sheet.
  Future<void> openSheet(
    WidgetTester tester, {
    int count = 6,
    int start = 0,
    int playNext = 0,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
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
    if (playNext > 0) {
      await player().playNext(named(playNext, prefix: 'p'));
    }
    backend.calls.clear();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show now playing list'));
    await tester.pumpAndSettle();
  }

  /// The row of a track, whether it is a plain row or the Now playing one.
  Finder tile(String title) => find.byWidgetPredicate(
    (w) =>
        (w is QueueTile && w.track.title == title) ||
        (w is QueueNowPlayingTile && w.track.title == title),
  );

  /// How many rows are built, of either kind.
  int rowsBuilt() =>
      find.byType(QueueTile).evaluate().length +
      find.byType(QueueNowPlayingTile).evaluate().length;

  Finder handleOf(String title) => find.descendant(
    of: tile(title),
    matching: find.byIcon(Icons.drag_handle_rounded),
  );

  /// Drags a handle by [dy] in small steps so the list sees every row.
  Future<void> drag(WidgetTester tester, Finder handle, double dy) async {
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

  /// The lifted copy of a row while it is dragged.
  Finder dragging(String title) => find.descendant(
    of: find.byWidgetPredicate((w) => w is Material && w.elevation > 0),
    matching: tile(title),
  );

  Future<void> openMenu(WidgetTester tester, String title) async {
    await tester.tap(tile(title), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  group('sections', () {
    testWidgets('label the upcoming tracks, with Play next only when queued', (
      tester,
    ) async {
      await openSheet(tester);
      expect(find.text('Up next'), findsOneWidget);
      expect(find.textContaining('Play next ('), findsNothing);
      expect(run(), 0);
    });

    testWidgets('show the Play next count above an Up next header row', (
      tester,
    ) async {
      await openSheet(tester, playNext: 2);

      expect(run(), 2);
      expect(find.text('Play next (2)'), findsOneWidget);
      expect(find.text('Up next'), findsOneWidget);
      // Now playing, 2 queued, header, then the rest: header sits between.
      final ys = [
        for (final t in ['t0', 'p0', 'p1', 't1']) tester.getTopLeft(tile(t)).dy,
      ];
      final header = tester.getTopLeft(find.text('Up next')).dy;
      expect(ys, orderedEquals([...ys]..sort()));
      expect(header, greaterThan(ys[2]));
      expect(header, lessThan(ys[3] + 64));
    });

    testWidgets('a single track has no label at all', (tester) async {
      await openSheet(tester, count: 1);
      expect(find.text('Up next'), findsNothing);
      expect(find.textContaining('Earlier'), findsNothing);
    });

    testWidgets('earlier tracks are folded away, and absent from the start', (
      tester,
    ) async {
      await openSheet(tester);
      expect(find.textContaining('Earlier'), findsNothing);
    });

    testWidgets('the Earlier toggle is collapsed and its rows are not built', (
      tester,
    ) async {
      await openSheet(tester, start: 3);

      expect(find.text('Earlier (3)'), findsOneWidget);
      expect(tile('t0'), findsNothing);
      expect(tile('t3'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Earlier (3)')).dy,
        lessThan(tester.getTopLeft(tile('t3')).dy),
      );
    });

    testWidgets('expanding shows the newest earlier tracks above Now playing', (
      tester,
    ) async {
      await openSheet(tester, count: 12, start: 8);

      await tester.tap(find.text('Earlier (8)'));
      await tester.pumpAndSettle();

      double y(String title) => tester.getTopLeft(tile(title)).dy;
      expect(y('t7'), lessThan(y('t8')));
      expect(y('t6'), lessThan(y('t7')));
      expect(y('t5'), lessThan(y('t6')));
      // The newest is nearest to the toggle and the playing track.
      // Only the toggle sits between the newest earlier row and Now playing.
      expect(y('t8') - y('t7'), 56 + 40);
      expect(tester.getTopLeft(find.text('Earlier (8)')).dy, lessThan(y('t8')));

      await tester.tap(find.text('Earlier (8)'));
      await tester.pumpAndSettle();
      expect(tile('t7'), findsNothing);
      expect(tile('t8'), findsOneWidget);
    });

    testWidgets('tapping an earlier row plays it again', (tester) async {
      await openSheet(tester, start: 3);
      await tester.tap(find.text('Earlier (3)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('t2'));
      await tester.pumpAndSettle();

      expect(container.read(playerServiceProvider).queue.current!.title, 't2');
    });

    testWidgets('earlier rows have no drag handle', (tester) async {
      await openSheet(tester, start: 2);
      await tester.tap(find.text('Earlier (2)'));
      await tester.pumpAndSettle();

      expect(handleOf('t1'), findsNothing);
      expect(handleOf('t3'), findsOneWidget);
    });

    testWidgets('repeat all ends the list with a restart row', (tester) async {
      await openSheet(tester, count: 3);
      expect(find.text('Then the queue starts over'), findsNothing);

      await player().cycleRepeat();
      await tester.pumpAndSettle();

      expect(find.text('Then the queue starts over'), findsOneWidget);
    });
  });

  group('toggle', () {
    testWidgets('Enter on the focused toggle expands it', (tester) async {
      await openSheet(tester, start: 2);
      Focus.of(tester.element(find.text('Earlier (2)'))).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(tile('t1'), findsOneWidget);
    });

    testWidgets('Space on the focused toggle still plays and pauses', (
      tester,
    ) async {
      await openSheet(tester, start: 2);
      Focus.of(tester.element(find.text('Earlier (2)'))).requestFocus();
      await tester.pump();
      expect(container.read(playerServiceProvider).playing, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(container.read(playerServiceProvider).playing, isFalse);
      expect(tile('t1'), findsNothing);
    });

    testWidgets('is a button that reports whether it is expanded', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openSheet(tester, start: 2);

      SemanticsNode node() => tester.getSemantics(find.text('Earlier (2)'));
      expect(node().flagsCollection.isButton, isTrue);
      expect(node().flagsCollection.isExpanded, Tristate.isFalse);
      await tester.tap(find.text('Earlier (2)'));
      await tester.pumpAndSettle();
      expect(node().flagsCollection.isExpanded, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('exposes a tap action that expands it', (tester) async {
      final handle = tester.ensureSemantics();
      await openSheet(tester, start: 2);
      final node = tester.getSemantics(find.text('Earlier (2)'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      tester.semantics.tap(find.semantics.byLabel('Earlier (2)'));
      await tester.pumpAndSettle();

      expect(tile('t1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('stays expanded after the filter is opened and closed', (
      tester,
    ) async {
      await openSheet(tester, start: 2);
      await tester.tap(find.text('Earlier (2)'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(QueuePanel),
          matching: find.byTooltip('Filter in this page'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(QueuePanel),
          matching: find.byTooltip('Filter in this page'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tile('t1'), findsOneWidget);
    });
  });

  group('moving between sections', () {
    testWidgets('dragging an Up next row above the header joins Play next', (
      tester,
    ) async {
      await openSheet(tester, playNext: 2);
      expect(run(), 2);

      await drag(tester, handleOf('t1'), -72);

      expect(run(), 3);
      expect(titles().take(4), ['t0', 'p0', 'p1', 't1']);
    });

    testWidgets('dragging the last Play next row below the header leaves it', (
      tester,
    ) async {
      await openSheet(tester, playNext: 2);

      await drag(tester, handleOf('p1'), 72);

      expect(run(), 1);
      expect(titles().take(4), ['t0', 'p0', 'p1', 't1']);
    });

    testWidgets('reordering inside Play next keeps both in it', (tester) async {
      await openSheet(tester, playNext: 2);

      await drag(tester, handleOf('p0'), 72);

      expect(run(), 2);
      expect(titles().take(4), ['t0', 'p1', 'p0', 't1']);
    });

    testWidgets('a track dragged far into Play next from Up next joins it', (
      tester,
    ) async {
      await openSheet(tester, playNext: 2);

      await drag(tester, handleOf('t2'), -230);

      expect(run(), 3);
      expect(titles().take(4), ['t0', 't2', 'p0', 'p1']);
    });

    testWidgets('moving the header with a semantics action does nothing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openSheet(tester, playNext: 2);
      final before = titles();

      final node = tester.getSemantics(find.text('Up next'));
      final actions = node.getSemanticsData().customSemanticsActionIds;
      // The list advertises its move actions on every row, header included.
      expect(actions, isNotEmpty);
      for (final id in actions ?? <int>[]) {
        tester.binding.rootPipelineOwner.semanticsOwner!.performAction(
          node.id,
          SemanticsAction.customAction,
          id,
        );
      }
      await tester.pumpAndSettle();

      expect(titles(), before);
      expect(run(), 2);
      handle.dispose();
    });

    testWidgets('the row menu moves a track to Play next and back', (
      tester,
    ) async {
      await openSheet(tester, playNext: 1);

      await openMenu(tester, 't3');
      await tester.tap(find.text('Move to Play next'));
      await tester.pumpAndSettle();

      expect(run(), 2);
      expect(titles().take(4), ['t0', 'p0', 't3', 't1']);

      await openMenu(tester, 't3');
      expect(find.text('Move to Play next'), findsNothing);
      await tester.tap(find.text('Remove from Play next'));
      await tester.pumpAndSettle();

      expect(run(), 1);
      expect(titles().take(4), ['t0', 'p0', 't3', 't1']);
    });

    testWidgets('the menu offers no move on the playing track', (tester) async {
      await openSheet(tester, playNext: 1);

      await openMenu(tester, 't0');

      expect(find.text('Move to Play next'), findsNothing);
      expect(find.text('Remove from Play next'), findsNothing);
      expect(find.text('Remove from queue'), findsOneWidget);
    });

    testWidgets('an earlier track moves to the end of Play next', (
      tester,
    ) async {
      await openSheet(tester, start: 2, playNext: 1);
      await tester.tap(find.text('Earlier (2)'));
      await tester.pumpAndSettle();

      await openMenu(tester, 't0');
      await tester.tap(find.text('Move to Play next'));
      await tester.pumpAndSettle();

      expect(run(), 2);
      expect(container.read(playerServiceProvider).queue.current!.title, 't2');
      expect(titles().skip(1).take(4), ['t2', 'p0', 't0', 't3']);
    });
  });

  group('while the queue changes', () {
    testWidgets('a drag that spans a track change moves nothing', (
      tester,
    ) async {
      await openSheet(tester);
      final before = titles();
      final gesture = await tester.startGesture(
        tester.getCenter(handleOf('t3')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -8));
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(dragging('t3'), findsOneWidget);

      await player().next();
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(titles(), before);
      expect(container.read(playerServiceProvider).queue.current!.title, 't1');
    });

    testWidgets('a drag does not drop after a shuffle that keeps the rows', (
      tester,
    ) async {
      await openSheet(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(handleOf('t3')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(dragging('t3'), findsOneWidget);

      await player().setShuffle(true);
      await tester.pump();
      final shuffled = titles();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(titles(), shuffled);
      expect(dragging('t3'), findsNothing);
    });

    testWidgets('a drag does not drop after Previous that keeps the rows', (
      tester,
    ) async {
      await openSheet(tester, start: 2, playNext: 1);
      final gesture = await tester.startGesture(
        tester.getCenter(handleOf('t4')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(dragging('t4'), findsOneWidget);
      final before = titles();

      await player().previous();
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(titles(), before);
      expect(run(), 0);
    });

    testWidgets('dragging to the top with Earlier open joins Play next first', (
      tester,
    ) async {
      await openSheet(tester, count: 10, start: 4, playNext: 2);
      await tester.tap(find.text('Earlier (4)'));
      await tester.pumpAndSettle();

      await drag(tester, handleOf('t5'), -600);

      expect(tester.takeException(), isNull);
      expect(run(), 3);
      expect(titles().skip(4).take(4), ['t4', 't5', 'p0', 'p1']);
    });

    testWidgets('focus stays on a row moved with its menu', (tester) async {
      await openSheet(tester, playNext: 1);
      Focus.of(tester.element(find.text('t3'))).requestFocus();
      await tester.pump();

      await openMenu(tester, 't3');
      await tester.tap(find.text('Move to Play next'));
      await tester.pumpAndSettle();

      expect(run(), 2);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<QueueTile>()
            ?.track
            .title,
        't3',
      );
    });

    testWidgets('keyboard focus stays on its row when the track advances', (
      tester,
    ) async {
      await openSheet(tester);
      Focus.of(tester.element(find.text('t3'))).requestFocus();
      await tester.pump();
      String? focused() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<QueueTile>()
          ?.track
          .title;
      expect(focused(), 't3');

      await player().next();
      await tester.pumpAndSettle();

      expect(container.read(playerServiceProvider).queue.current!.title, 't1');
      expect(focused(), 't3');
    });

    testWidgets('locating the playing track scrolls to offset 0', (
      tester,
    ) async {
      await openSheet(tester, count: 80, start: 2);
      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable.first).position.pixels,
        greaterThan(0),
      );

      await tester.tap(find.byTooltip('Jump to current song'));
      await tester.pumpAndSettle();

      expect(
        tester.state<ScrollableState>(scrollable.first).position.pixels,
        0,
      );
      expect(tile('t2'), findsOneWidget);
    });
  });

  group('50 000 tracks', () {
    testWidgets('build under 50 rows at open and after expanding 40 000', (
      tester,
    ) async {
      await openSheet(tester, count: 50000, start: 40000);
      expect(rowsBuilt(), lessThan(50));
      expect(tile('t40000'), findsOneWidget);

      await tester.tap(find.text('Earlier (40000)'));
      await tester.pumpAndSettle();

      expect(rowsBuilt(), lessThan(50));
      expect(tile('t39999'), findsOneWidget);
      expect(tile('t40000'), findsOneWidget);
    });
  });
}
