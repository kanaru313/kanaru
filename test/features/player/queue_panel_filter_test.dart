import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/play_queue.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/queue/queue_filter_results.dart';
import 'package:kanaru/shared/in_page_filter.dart';
import 'package:kanaru/features/player/queue/queue_panel.dart';
import 'package:kanaru/features/player/queue/queue_tile.dart';
import 'package:kanaru/shared/in_page_filter_registry.dart';
import 'package:kanaru/shared/widgets/in_page_search_field.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

const _tracks = [
  Track(uri: '/m/a.mp3', title: 'alpha one', artist: 'Zed'),
  Track(uri: '/m/b.mp3', title: 'beta two', artist: 'One Direction'),
  Track(uri: '/m/c.mp3', title: 'one gamma', artist: 'Zed'),
  Track(uri: '/m/d.mp3', title: 'delta', artist: 'Zed'),
];

void main() {
  late ProviderContainer container;

  PlayerService player() => container.read(playerServiceProvider.notifier);
  Track? current() => container.read(playerServiceProvider).queue.current;
  List<String> queueTitles() => [
    for (final t in container.read(playerServiceProvider).queue.tracks) t.title,
  ];
  List<String> rows(WidgetTester tester) => [
    for (final tile in tester.widgetList<QueueTile>(find.byType(QueueTile)))
      tile.track.title,
  ];

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(FakeAudioBackend())],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KanaruApp(locale: Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
    await player().openTracks(_tracks);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show now playing list'));
    await tester.pumpAndSettle();
  }

  Future<void> filterBy(WidgetTester tester, String text) async {
    if (find.byType(InPageSearchBox).evaluate().isEmpty) {
      await tester.tap(
        find.descendant(
          of: find.byType(QueuePanel),
          matching: find.byTooltip('Filter in this page'),
        ),
      );
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.descendant(
        of: find.byType(InPageSearchBox),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pump(const Duration(milliseconds: 150));
  }

  testWidgets('filters the rows, title matches before artist matches', (
    tester,
  ) async {
    await openSheet(tester);
    expect(rows(tester), hasLength(4));

    await filterBy(tester, 'one');

    // "one gamma" starts with it, "alpha one" has it in the title, the third
    // has it only in the artist.
    expect(rows(tester), ['one gamma', 'alpha one', 'beta two']);
    expect(queueTitles(), [for (final t in _tracks) t.title]);
  });

  testWidgets('filtered rows cannot be dragged or removed', (tester) async {
    await openSheet(tester);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(4));

    await filterBy(tester, 'one');

    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    expect(find.byIcon(Icons.delete_rounded), findsNothing);
    expect(find.byType(ReorderableListView), findsNothing);
  });

  testWidgets('tapping a row jumps to it without changing the queue', (
    tester,
  ) async {
    await openSheet(tester);
    await filterBy(tester, 'one');

    await tester.tap(find.text('beta two'));
    await tester.pumpAndSettle();

    expect(current()?.title, 'beta two');
    expect(queueTitles(), [for (final t in _tracks) t.title]);
    expect(rows(tester), ['one gamma', 'alpha one', 'beta two']);
  });

  testWidgets('no match says so; Esc closes the box but not the sheet', (
    tester,
  ) async {
    await openSheet(tester);

    await filterBy(tester, 'zzz');
    expect(find.text('No songs match “zzz”'), findsOneWidget);
    expect(rows(tester), isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(InPageSearchBox), findsNothing);
    expect(find.byType(QueuePanel), findsOneWidget);
    expect(rows(tester), hasLength(4));
  });

  testWidgets('the header button toggles the box', (tester) async {
    await openSheet(tester);
    final button = find.descendant(
      of: find.byType(QueuePanel),
      matching: find.byTooltip('Filter in this page'),
    );

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(InPageSearchBox), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(InPageSearchBox), findsNothing);
  });

  testWidgets('the header button closes an empty, focused box with one tap', (
    tester,
  ) async {
    await openSheet(tester);
    final button = find.descendant(
      of: find.byType(QueuePanel),
      matching: find.byTooltip('Filter in this page'),
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(InPageFilterRegistry.instance.hasFocus, isTrue);

    // A real press and release on the button, with the box focused and empty.
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(InPageSearchBox), findsNothing, reason: 'not reopened');
  });

  test(
    'the queue index survives jumps and moves, and tracks index removals',
    () {
      var folded = 0;
      final view = InPageFilterView<Track>((t) {
        folded++;
        return (title: t.title, artist: t.artist, album: null);
      });
      var queue = PlayQueue.open(_tracks, 0);
      expect(queueFilterPositions(queue, view, ['one']), [2, 0, 1]);
      expect(folded, _tracks.length);

      queue = queue.copyWith(index: 2);
      queue = queue.move(2, 0);
      expect(queueFilterPositions(queue, view, ['one']), [0, 1, 2]);
      expect(folded, _tracks.length, reason: 'jump and move do not fold again');

      queue = queue.copyWith(
        order: [
          for (final e in queue.order)
            if (e != 1) e,
        ],
      );
      expect(queueFilterPositions(queue, view, ['one']), [0, 1]);
    },
  );

  test('inside one tier the matches follow the play order', () {
    final view = InPageFilterView<Track>(
      (t) => (title: t.title, artist: t.artist, album: null),
    );
    // Artist "Zed" matches a, c and d in the same tier.
    var queue = PlayQueue.open(_tracks, 0);
    expect(queueFilterPositions(queue, view, ['zed']), [0, 2, 3]);
    queue = queue.move(3, 0);
    // Order is now d, a, b, c: a, c, d sit at 1, 3, 0, not in load order.
    expect(queueFilterPositions(queue, view, ['zed']), [0, 1, 3]);
  });

  testWidgets('the jump button closes the filter first', (tester) async {
    await openSheet(tester);
    await filterBy(tester, 'one');
    expect(find.byType(InPageSearchBox), findsOneWidget);

    await tester.tap(find.byTooltip('Jump to current song'));
    await tester.pumpAndSettle();

    expect(find.byType(InPageSearchBox), findsNothing);
    expect(rows(tester), isNotEmpty);
  });

  testWidgets('Ctrl+F with the sheet open reaches the queue, not the page', (
    tester,
  ) async {
    await openSheet(tester);
    var pageOpened = false;
    final pageHandle = InPageFilterHandle(
      context: tester.element(find.byType(QueuePanel)),
      open: () => pageOpened = true,
      hasFocus: () => false,
    );
    InPageFilterRegistry.instance.register(pageHandle);
    addTearDown(() => InPageFilterRegistry.instance.unregister(pageHandle));

    expect(InPageFilterRegistry.instance.openTop(), isTrue);
    await tester.pumpAndSettle();

    expect(pageOpened, isFalse);
    expect(find.byType(InPageSearchBox), findsOneWidget);
    expect(InPageFilterRegistry.instance.hasFocus, isTrue);
  });

  testWidgets('closing the sheet drops the filter and the registration', (
    tester,
  ) async {
    await openSheet(tester);
    await filterBy(tester, 'one');

    await tester.tap(find.byTooltip('Close now playing list'));
    await tester.pumpAndSettle();
    expect(find.byType(QueuePanel), findsNothing);
    expect(InPageFilterRegistry.instance.openTop(), isFalse);

    await tester.tap(find.byTooltip('Show now playing list'));
    await tester.pumpAndSettle();
    expect(find.byType(InPageSearchBox), findsNothing);
    expect(rows(tester), hasLength(4));
  });
}
