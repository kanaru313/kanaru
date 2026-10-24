import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/home/home_shelf.dart';
import 'package:kanaru/features/home/home_tile_metrics.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'home_test_harness.dart';

void main() {
  Widget shelf(int count) => HomeShelf(
    itemCount: count,
    itemBuilder: (_, i) => Center(child: Text('card $i')),
  );

  final back = find.byIcon(AppIcons.chevronLeft);
  final forward = find.byIcon(AppIcons.chevronRight);

  double offset(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

  testWidgets('a shelf that fits shows no arrows', (tester) async {
    await HomeHarness().pump(tester, shelf(3));
    expect(back, findsNothing);
    expect(forward, findsNothing);
  });

  testWidgets('arrows appear only on the side with more cards', (tester) async {
    await HomeHarness().pump(tester, shelf(30));
    expect(back, findsNothing);
    expect(forward, findsOneWidget);

    await tester.tap(forward);
    await tester.pumpAndSettle();
    // 80 % of the 1280 px viewport.
    expect(offset(tester), closeTo(1024, 1));
    expect(back, findsOneWidget);

    for (var i = 0; i < 10; i++) {
      if (forward.evaluate().isEmpty) break;
      await tester.tap(forward);
      await tester.pumpAndSettle();
    }
    expect(forward, findsNothing);
    expect(back, findsOneWidget);

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(forward, findsOneWidget);
  });

  testWidgets('a shelf that shrinks while scrolled drops its arrows', (
    tester,
  ) async {
    final h = HomeHarness();
    final count = ValueNotifier(30);
    addTearDown(count.dispose);
    await h.pump(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: count,
        builder: (_, n, _) => shelf(n),
      ),
    );
    await tester.tap(forward);
    await tester.pumpAndSettle();
    expect(back, findsOneWidget);

    count.value = 3;
    await tester.pumpAndSettle();
    expect(back, findsNothing);
    expect(forward, findsNothing);
  });

  testWidgets('arrows sit on the vertical centre of the cover', (tester) async {
    await HomeHarness().pump(tester, shelf(30));
    final shelfBox = find.byType(HomeShelf);
    final centre =
        tester.getTopLeft(shelfBox).dy +
        homeCardPadding +
        homeCardPictureSize / 2;
    expect(tester.getCenter(forward).dy, closeTo(centre, 0.5));
  });

  testWidgets('arrows have tooltips', (tester) async {
    await HomeHarness().pump(tester, shelf(30));
    expect(find.byTooltip('Scroll forward'), findsOneWidget);
  });

  testWidgets('reduced motion jumps at once', (tester) async {
    await HomeHarness().pump(tester, shelf(30), disableAnimations: true);
    await tester.tap(forward);
    await tester.pump();
    expect(offset(tester), closeTo(1024, 1));
  });

  testWidgets('the mouse drags the shelf', (tester) async {
    await HomeHarness().pump(tester, shelf(30));
    final gesture = await tester.startGesture(
      const Offset(600, 100),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(-300, 0));
    await gesture.moveBy(const Offset(-300, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(offset(tester), greaterThan(300));
    expect(back, findsOneWidget);
  });

  testWidgets('cards are a fixed width', (tester) async {
    await HomeHarness().pump(tester, shelf(30));
    expect(
      tester.getSize(find.text('card 0').first).width,
      lessThanOrEqualTo(homeShelfTileWidth),
    );
    expect(
      tester.getTopLeft(find.text('card 1')).dx -
          tester.getTopLeft(find.text('card 0')).dx,
      homeShelfTileWidth,
    );
  });
}
