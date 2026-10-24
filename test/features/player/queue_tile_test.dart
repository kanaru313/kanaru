import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/queue/queue_now_playing_tile.dart';
import 'package:kanaru/features/player/queue/queue_swipe_gate.dart';
import 'package:kanaru/features/player/queue/queue_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

List<Track> named(int count, {String? artUri}) => [
  for (var i = 0; i < count; i++)
    Track(
      uri: '/music/t$i.mp3',
      title: 't$i',
      artist: 'artist $i',
      artUri: artUri,
    ),
];

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;
  TestGesture? mouse;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  List<String> titles() => [
    for (final t in container.read(playerServiceProvider).queue.tracks) t.title,
  ];
  String? current() =>
      container.read(playerServiceProvider).queue.current?.title;

  /// The row of a track, plain or Now playing.
  Finder row(String title) => find.byWidgetPredicate(
    (w) =>
        (w is QueueTile && w.track.title == title) ||
        (w is QueueNowPlayingTile && w.track.title == title),
  );

  Finder removeOf(String title) => find.descendant(
    of: row(title),
    matching: find.byTooltip('Remove from queue'),
  );

  Finder handleOf(String title) => find.descendant(
    of: row(title),
    matching: find.byIcon(Icons.drag_handle_rounded),
  );

  /// Whether a control of a row can be pressed: hidden ones stay in the
  /// tree but are not hit-testable.
  bool isShown(WidgetTester tester, Finder control) =>
      control.hitTestable().evaluate().isNotEmpty;

  Future<void> pumpSheet(
    WidgetTester tester, {
    int count = 5,
    int start = 0,
    String? artUri,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    mouse = null;
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
    await player().openTracks(named(count, artUri: artUri), start: start);
    backend.calls.clear();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show now playing list'));
    await tester.pumpAndSettle();
  }

  /// Moves a mouse over the centre of [target], or off the sheet.
  Future<void> hover(WidgetTester tester, Finder? target) async {
    var gesture = mouse;
    if (gesture == null) {
      gesture = mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
    }
    await gesture.moveTo(
      target == null ? Offset.zero : tester.getCenter(target),
    );
    await tester.pump();
  }

  /// Makes the app see a mouse: a touch-first window keeps the drag handles
  /// in view, so tests of hover start from a mouse that has moved over rows.
  Future<void> useMouse(WidgetTester tester) async {
    await hover(tester, row('t4'));
    await hover(tester, null);
  }

  /// A touch that is not a tap or a drag, so the window sees touch input and
  /// nothing else happens.
  Future<void> touchPoke(WidgetTester tester, Finder target) async {
    final gesture = await tester.startGesture(tester.getCenter(target));
    await gesture.moveBy(const Offset(0, -40));
    await gesture.up();
    await tester.pump();
  }

  /// Lets a swiped row finish and its removal run (it waits for the list to
  /// be quiet).
  Future<void> settleSwipe(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(QueueSwipeGate.quiet + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }

  group('actions', () {
    testWidgets('show while the mouse is over the row and hide after', (
      tester,
    ) async {
      await pumpSheet(tester);
      await useMouse(tester);
      expect(isShown(tester, removeOf('t1')), isFalse);
      expect(isShown(tester, handleOf('t1')), isFalse);

      await hover(tester, row('t1'));
      expect(isShown(tester, removeOf('t1')), isTrue);
      expect(isShown(tester, handleOf('t1')), isTrue);
      expect(isShown(tester, removeOf('t2')), isFalse);

      await hover(tester, row('t2'));
      expect(isShown(tester, removeOf('t1')), isFalse);
      expect(isShown(tester, removeOf('t2')), isTrue);

      await hover(tester, null);
      expect(isShown(tester, removeOf('t2')), isFalse);
    });

    testWidgets('the playing row shows remove on hover and has no handle', (
      tester,
    ) async {
      await pumpSheet(tester);
      expect(handleOf('t0'), findsNothing);
      await hover(tester, null);
      expect(isShown(tester, removeOf('t0')), isFalse);

      await hover(tester, row('t0'));

      expect(isShown(tester, removeOf('t0')), isTrue);
    });

    testWidgets('a tap where the hidden remove button sits removes nothing', (
      tester,
    ) async {
      await pumpSheet(tester);
      await useMouse(tester);
      final spot = tester.getCenter(removeOf('t2'));

      await tester.tapAt(spot);
      await tester.pumpAndSettle();

      expect(titles(), ['t0', 't1', 't2', 't3', 't4']);
      // The tap landed on the row, which plays it.
      expect(current(), 't2');
    });

    testWidgets('are still named for screen readers while hidden', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSheet(tester);
      await useMouse(tester);

      expect(isShown(tester, removeOf('t2')), isFalse);
      final remove = tester.getSemantics(
        find.descendant(
          of: row('t2'),
          matching: find.bySemanticsLabel('Remove from queue'),
        ),
      );
      expect(remove.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        find.descendant(
          of: row('t2'),
          matching: find.bySemanticsLabel('Drag to reorder'),
        ),
        findsOneWidget,
      );
      // The row itself offers remove as an action, which works while the
      // button is hidden (a hidden button's own actions are blocked).
      final data = tester
          .getSemantics(
            find
                .descendant(of: row('t2'), matching: find.byType(InkWell))
                .first,
          )
          .getSemanticsData();
      expect([
        for (final id in data.customSemanticsActionIds ?? <int>[])
          CustomSemanticsAction.getAction(id)?.label,
      ], contains('Remove from queue'));
      semantics.dispose();
    });

    testWidgets(
      'Tab onto a row reveals remove, the next Tab and Enter use it',
      (tester) async {
        await pumpSheet(tester);
        await useMouse(tester);
        Focus.of(tester.element(find.text('t2'))).requestFocus();
        await tester.pumpAndSettle();
        expect(isShown(tester, removeOf('t2')), isTrue);
        expect(isShown(tester, removeOf('t3')), isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(titles(), ['t0', 't1', 't3', 't4']);
      },
    );

    testWidgets('the handle stays in view after a touch, remove does not', (
      tester,
    ) async {
      await pumpSheet(tester);
      await useMouse(tester);
      expect(isShown(tester, handleOf('t3')), isFalse);

      await touchPoke(tester, find.text('t3'));

      expect(isShown(tester, handleOf('t3')), isTrue);
      expect(isShown(tester, removeOf('t3')), isFalse);
    });
  });

  group('swipe', () {
    testWidgets('a finger swiping from the end removes the row', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tester.drag(find.text('t2'), const Offset(-300, 0));
      await settleSwipe(tester);

      expect(titles(), ['t0', 't1', 't3', 't4']);
    });

    testWidgets('two rows swiped one right after the other both go', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tester.drag(find.text('t1'), const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.drag(find.text('t2'), const Offset(-300, 0));
      await settleSwipe(tester);

      expect(titles(), ['t0', 't3', 't4']);
    });

    testWidgets('a track change while the swipe settles keeps the removal', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tester.drag(find.text('t3'), const Offset(-300, 0));
      // The row is off screen and swiped, but not yet removed from the queue.
      await tester.pump(const Duration(milliseconds: 250));
      expect(titles(), hasLength(5));
      await player().next();
      await settleSwipe(tester);

      expect(current(), 't1');
      expect(titles(), ['t0', 't1', 't2', 't4']);
    });

    testWidgets('a swipe is dropped when the queue is replaced meanwhile', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tester.drag(find.text('t2'), const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await player().openTracks([
        for (var i = 0; i < 5; i++) Track(uri: '/new/n$i.mp3', title: 'n$i'),
      ]);
      await settleSwipe(tester);

      expect(tester.takeException(), isNull);
      expect(titles(), ['n0', 'n1', 'n2', 'n3', 'n4']);
    });

    testWidgets('a swipe is dropped when the queue shrinks meanwhile', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tester.drag(find.text('t4'), const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await player().openTracks([
        for (var i = 0; i < 2; i++) Track(uri: '/new/n$i.mp3', title: 'n$i'),
      ]);
      await settleSwipe(tester);

      expect(tester.takeException(), isNull);
      expect(titles(), ['n0', 'n1']);
    });

    testWidgets('closing the list removes a swiped row that was waiting', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tester.drag(find.text('t2'), const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 300));
      // Let the swipe be recorded; the list is still within its quiet time.
      await tester.pump(const Duration(milliseconds: 50));
      expect(titles(), hasLength(5));
      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
      expect(titles(), ['t0', 't1', 't3', 't4']);
    });

    testWidgets('a swipe toward the end does nothing', (tester) async {
      await pumpSheet(tester);

      await tester.drag(find.text('t2'), const Offset(300, 0));
      await tester.pumpAndSettle();

      expect(titles(), ['t0', 't1', 't2', 't3', 't4']);
    });

    testWidgets('a mouse drag does not remove the row', (tester) async {
      await pumpSheet(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('t2')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(-150, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-150, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(titles(), ['t0', 't1', 't2', 't3', 't4']);
      expect(row('t2'), findsOneWidget);
    });

    testWidgets('a trackpad pan does not remove the row, even after a touch', (
      tester,
    ) async {
      await pumpSheet(tester);
      await tester.tap(find.text('t1'));
      await tester.pumpAndSettle();
      final start = tester.getCenter(find.text('t3'));

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await gesture.panZoomStart(start);
      await gesture.panZoomUpdate(start, pan: const Offset(-150, 0));
      await tester.pump();
      await gesture.panZoomUpdate(start, pan: const Offset(-300, 0));
      await tester.pump();
      await gesture.panZoomEnd();
      await tester.pumpAndSettle();

      expect(titles(), ['t0', 't1', 't2', 't3', 't4']);
    });

    testWidgets('the swipe is always built, whatever the input', (
      tester,
    ) async {
      await pumpSheet(tester);
      final before = find.byType(Dismissible).evaluate().length;
      expect(before, 4);

      await hover(tester, row('t2'));
      expect(find.byType(Dismissible).evaluate().length, before);
      await touchPoke(tester, find.text('t3'));
      expect(find.byType(Dismissible).evaluate().length, before);
    });

    testWidgets('the playing row cannot be swiped away', (tester) async {
      await pumpSheet(tester);

      expect(
        find.descendant(
          of: find.byType(QueueNowPlayingTile),
          matching: find.byType(Dismissible),
        ),
        findsNothing,
      );
    });

    testWidgets('a mouse click right after a touch tap still plays the row', (
      tester,
    ) async {
      await pumpSheet(tester);
      await tester.tap(find.text('t1'));
      await tester.pumpAndSettle();
      expect(current(), 't1');

      await tester.tapAt(
        tester.getCenter(find.text('t3')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(current(), 't3');
      expect(titles(), ['t0', 't1', 't2', 't3', 't4']);
    });
  });

  group('drag', () {
    testWidgets('the lifted row keeps its handle in view for touch', (
      tester,
    ) async {
      await pumpSheet(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(handleOf('t2')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, 8));
        await tester.pump(const Duration(milliseconds: 16));
      }

      final handle = find.descendant(
        of: find.byWidgetPredicate((w) => w is Material && w.elevation > 0),
        matching: find.byIcon(Icons.drag_handle_rounded),
      );
      expect(handle, findsOneWidget);
      expect(
        tester
            .widget<Visibility>(
              find
                  .ancestor(of: handle, matching: find.byType(Visibility))
                  .first,
            )
            .visible,
        isTrue,
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('layout', () {
    testWidgets('rows fit two lines at twice the text size', (tester) async {
      await pumpSheet(tester, textScale: 2);

      expect(tester.takeException(), isNull);
      final height = tester.getSize(find.byType(QueueTile).first).height;
      expect(height, greaterThan(90));
      final title = tester.getSize(find.text('t1')).height;
      final artist = tester.getSize(find.text('artist 1')).height;
      expect(title + artist, lessThanOrEqualTo(height - 16 + 0.5));
      // Rows are all the same height whatever the scale.
      expect(tester.getSize(find.byType(QueueTile).last).height, height);
    });

    testWidgets('section labels and the Earlier toggle fit at twice the text '
        'size', (tester) async {
      await pumpSheet(tester, textScale: 2, start: 1);
      await player().playNext([Track(uri: '/music/p0.mp3', title: 'p0')]);
      await tester.pumpAndSettle();

      for (final label in ['Earlier (1)', 'Play next (1)']) {
        final text = find.text(label);
        expect(text, findsOneWidget);
        final slot = find.ancestor(of: text, matching: find.byType(SizedBox));
        final height = tester.getSize(slot.first).height;
        expect(height, greaterThan(40));
        // The line and the 8 px under it fit the slot.
        expect(tester.getSize(text).height + 8, lessThanOrEqualTo(height));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('rows are 56 px tall at the default text size', (tester) async {
      await pumpSheet(tester);

      expect(tester.getSize(find.byType(QueueTile).first).height, 56);
      expect(tester.getSize(find.byType(QueueNowPlayingTile)).height, 72);
    });

    testWidgets('covers are decoded at the 128 px bucket', (tester) async {
      await pumpSheet(tester, artUri: '/music/cover.jpg');

      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(QueueTile).first,
          matching: find.byType(Image),
        ),
      );
      expect((image.image as ResizeImage).width, 128);
    });
  });

  group('focus', () {
    testWidgets('stays on the remove button of a row that becomes the '
        'playing one', (tester) async {
      await pumpSheet(tester);
      Focus.of(tester.element(find.text('t1'))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      await player().next();
      await tester.pumpAndSettle();

      expect(current(), 't1');
      final context = FocusManager.instance.primaryFocus?.context;
      expect(context?.findAncestorWidgetOfExactType<IconButton>(), isNotNull);
      expect(
        context?.findAncestorWidgetOfExactType<QueueNowPlayingTile>()?.track,
        isA<Track>().having((t) => t.title, 'title', 't1'),
      );
    });

    testWidgets('stays on the remove button when the track advances', (
      tester,
    ) async {
      await pumpSheet(tester);
      Focus.of(tester.element(find.text('t3'))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      bool onRemoveOf(String title) {
        final context = FocusManager.instance.primaryFocus?.context;
        return context != null &&
            context.findAncestorWidgetOfExactType<IconButton>() != null &&
            context.findAncestorWidgetOfExactType<QueueTile>()?.track.title ==
                title;
      }

      expect(onRemoveOf('t3'), isTrue);

      await player().next();
      await tester.pumpAndSettle();

      expect(current(), 't1');
      expect(onRemoveOf('t3'), isTrue);
    });
  });
}
