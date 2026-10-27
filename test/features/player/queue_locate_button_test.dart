import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/app.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/queue/queue_locate_button.dart';
import 'package:kanaru/features/player/queue/queue_panel.dart';
import 'package:kanaru/features/player/queue/queue_tile.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  group('locateSide', () {
    LocateSide side(double offset, int index) =>
        locateSide(offset: offset, viewport: 300, extent: 100, index: index);

    test('the row in view gives none', () {
      expect(side(0, 0), LocateSide.none);
      expect(side(0, 2), LocateSide.none);
      expect(side(150, 3), LocateSide.none);
    });

    test('a row partly in view at either edge gives none', () {
      expect(side(150, 1), LocateSide.none); // bottom 50 px visible
      expect(side(150, 4), LocateSide.none); // top 50 px visible
    });

    test('a row fully outside points toward it', () {
      expect(side(300, 0), LocateSide.up);
      expect(side(200, 1), LocateSide.up);
      expect(side(0, 3), LocateSide.down);
      expect(side(0, 9), LocateSide.down);
    });

    test('a row exactly touching the edge counts as outside', () {
      expect(side(100, 0), LocateSide.up);
      expect(side(0, 3), LocateSide.down);
    });

    test('bad input gives none', () {
      expect(side(0, -1), LocateSide.none);
      expect(
        locateSide(offset: 0, viewport: 300, extent: 0, index: 1),
        LocateSide.none,
      );
    });
  });

  late ProviderContainer container;
  PlayerService player() => container.read(playerServiceProvider.notifier);

  Future<void> openQueue(
    WidgetTester tester, {
    int count = 300,
    int start = 150,
    bool reduceMotion = true,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reduceMotion);
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
    await player().openTracks([
      for (var i = 0; i < count; i++)
        Track(uri: '/music/t$i.mp3', title: 't$i', artist: 'a$i'),
    ], start: start);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show now playing list'));
    await tester.pumpAndSettle();
  }

  Finder inList(Finder f) =>
      find.descendant(of: find.byType(QueuePanel), matching: f);
  Finder locate() => find.byType(QueueLocateButton);
  Finder locateIcon(IconData icon) =>
      find.descendant(of: locate(), matching: find.byIcon(icon));
  Finder button() =>
      find.descendant(of: locate(), matching: find.byType(IconButton));

  ScrollController scroll(WidgetTester tester) => tester
      .widget<ReorderableListView>(find.byType(ReorderableListView))
      .scrollController!;

  Future<void> scrollBy(WidgetTester tester, double dy) async {
    scroll(tester).jumpTo(scroll(tester).offset + dy);
    await tester.pumpAndSettle();
  }

  bool playingRowVisible(WidgetTester tester) => find
      .byType(QueueTile)
      .evaluate()
      .any((e) => (e.widget as QueueTile).current);

  testWidgets('is not built while the playing row is in view', (tester) async {
    await openQueue(tester);

    expect(button(), findsNothing);
    expect(playingRowVisible(tester), isTrue);
  });

  testWidgets('shows with an up arrow after scrolling past the row', (
    tester,
  ) async {
    await openQueue(tester);

    await scrollBy(tester, 2000);

    expect(button(), findsOneWidget);
    expect(locateIcon(AppIcons.locateUp), findsOneWidget);
  });

  testWidgets('shows with a down arrow when the row is below', (tester) async {
    await openQueue(tester, start: 250);
    await scrollBy(tester, -4000);

    expect(locateIcon(AppIcons.locateDown), findsOneWidget);
  });

  testWidgets('pressing it brings the playing row back and hides it', (
    tester,
  ) async {
    await openQueue(tester);
    await scrollBy(tester, 2000);

    await tester.tap(button());
    await tester.pumpAndSettle();

    expect(playingRowVisible(tester), isTrue);
    expect(button(), findsNothing);
  });

  testWidgets('the track advancing off screen shows it without a scroll', (
    tester,
  ) async {
    await openQueue(tester, start: 2);
    await scrollBy(tester, -10000);
    expect(button(), findsNothing);

    await player().jump(200);
    await tester.pumpAndSettle();

    expect(locateIcon(AppIcons.locateDown), findsOneWidget);
  });

  testWidgets('resizing the window rechecks the side', (tester) async {
    await openQueue(tester, start: 5);
    // Row 5 is 400 px down: in view in a tall window, below in a short one.
    scroll(tester).jumpTo(0);
    await tester.pumpAndSettle();
    expect(button(), findsNothing);

    tester.view.physicalSize = const Size(1280, 330);
    await tester.pumpAndSettle();

    expect(locateIcon(AppIcons.locateDown), findsOneWidget);
  });

  testWidgets('is not shown in a queue of one row', (tester) async {
    await openQueue(tester, count: 1, start: 0);

    expect(locate(), findsOneWidget);
    expect(button(), findsNothing);
  });

  testWidgets('filter open and close leaves the right state', (tester) async {
    await openQueue(tester);
    await scrollBy(tester, 2000);
    expect(button(), findsOneWidget);

    await tester.tap(inList(find.byTooltip('Filter in this page')));
    await tester.pumpAndSettle();
    await tester.enterText(inList(find.byType(TextField)), 't1');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(locate(), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(inList(find.byTooltip('Close')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(locate(), findsOneWidget);
    // The list is built again at the playing row.
    expect(button(), findsNothing);
    expect(playingRowVisible(tester), isTrue);

    await scrollBy(tester, 2000);
    expect(button(), findsOneWidget);
  });

  testWidgets('is hidden while a row is dragged', (tester) async {
    await openQueue(tester);
    await scrollBy(tester, 2000);
    expect(button(), findsOneWidget);

    // The first row that is on screen: rows built beyond the viewport edge
    // cannot be dragged.
    final handle = find
        .descendant(
          of: find.byType(QueueTile),
          matching: find.byIcon(Icons.drag_handle_rounded),
        )
        .hitTestable()
        .first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump(const Duration(milliseconds: 16));
    expect(button(), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(button(), findsOneWidget);
  });

  testWidgets('fades out over 150 ms under normal motion', (tester) async {
    await openQueue(tester, reduceMotion: false);
    await scrollBy(tester, 2000);
    expect(button(), findsOneWidget);
    Finder opacity() =>
        find.descendant(of: locate(), matching: find.byType(AnimatedOpacity));
    final fade = tester.widget<AnimatedOpacity>(opacity());
    expect(fade.duration, const Duration(milliseconds: 150));
    expect(fade.opacity, 1);

    // Back to the playing row at once, so the fade starts at a known frame.
    scroll(tester).jumpTo(149 * 88.0);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(opacity()).opacity, 0);
    await tester.pump(const Duration(milliseconds: 75));
    expect(button(), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(button(), findsNothing);
  });

  testWidgets('reduced motion has no fade', (tester) async {
    await openQueue(tester);
    await scrollBy(tester, 2000);

    final fading = find.descendant(
      of: locate(),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(fading).duration, Duration.zero);
  });

  testWidgets('has a semantics label and a tooltip', (tester) async {
    final handle = tester.ensureSemantics();
    await openQueue(tester);
    await scrollBy(tester, 2000);

    expect(
      find.descendant(
        of: locate(),
        matching: find.bySemanticsLabel('Jump to current song'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: locate(),
        matching: find.byTooltip('Jump to current song'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('crossing the threshold rebuilds no rows', (tester) async {
    await openQueue(tester);
    Set<Widget> rows() => {
      for (final e in find.byType(QueueTile).evaluate()) e.widget,
    };
    final top = scroll(tester).offset;
    final before = rows();
    scroll(tester).jumpTo(top + 88.0);
    await tester.pump();
    final mid = rows();
    expect(button(), findsNothing);

    // The playing row leaves the view here, and the button comes in.
    scroll(tester).jumpTo(top + 4 * 88.0);
    await tester.pump();
    await tester.pump();
    expect(button(), findsOneWidget);
    final after = rows();

    // Rows on screen on both sides of a step are the same instances.
    expect(before.intersection(mid), isNotEmpty);
    expect(mid.intersection(after), isNotEmpty);
  });

  testWidgets('the last row playing is in view with no button', (tester) async {
    await openQueue(tester, count: 500, start: 499);

    expect(button(), findsNothing);
    expect(playingRowVisible(tester), isTrue);
    final c = scroll(tester);
    expect(c.offset, c.position.maxScrollExtent);
  });

  testWidgets('does not hold a tab stop while hidden', (tester) async {
    await openQueue(tester);

    expect(
      find.descendant(of: locate(), matching: find.byType(Focus)),
      findsNothing,
    );
  });
}
