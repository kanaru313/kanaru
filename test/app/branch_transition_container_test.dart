import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/branch_transition_container.dart';
import 'package:material_ui/material_ui.dart';

/// A branch page that shows [label] plus a tap counter, to check that a
/// branch's state survives being switched away from and back to.
class _CounterPage extends StatefulWidget {
  const _CounterPage(this.label);

  final String label;

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _count++),
    child: Text('${widget.label}:$_count'),
  );
}

void main() {
  // Three branch pages, labelled so direction (A → B is towardsBelow,
  // matching AppDestination.home → AppDestination.songs) can be told apart
  // from position in the render tree.
  const children = [_CounterPage('A'), _CounterPage('B'), _CounterPage('C')];

  Widget harness({
    required int currentIndex,
    bool reducedMotion = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: BranchTransitionContainer(
        currentIndex: currentIndex,
        children: children,
      ),
    ),
  );

  double dyOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('first build shows only the initial branch, unanimated', (
    tester,
  ) async {
    await tester.pumpWidget(harness(currentIndex: 0));

    expect(find.text('A:0'), findsOneWidget);
    expect(find.text('B:0'), findsNothing);
    expect(find.text('C:0'), findsNothing);
    expect(
      find.text('B:0', skipOffstage: false),
      findsOneWidget,
      reason: 'mounted, just offstage, like every unvisited branch',
    );
  });

  testWidgets(
    'switching branches shows both pages mid-transition, new one translated '
    'towards below, old one towards above, then settles',
    (tester) async {
      await tester.pumpWidget(harness(currentIndex: 0));
      await tester.pumpWidget(harness(currentIndex: 1));

      // Mid-transition (home → songs is towardsBelow): both onstage.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('A:0'), findsOneWidget);
      expect(find.text('B:0'), findsOneWidget);
      // New page arrives from below: starts translated down (+), old page
      // is pushed up (-).
      expect(dyOf(tester, 'B:0'), greaterThan(0));
      expect(dyOf(tester, 'A:0'), lessThan(0));

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('A:0'), findsNothing, reason: 'now offstage');
      expect(find.text('B:0'), findsOneWidget);
      expect(dyOf(tester, 'B:0'), 0);
    },
  );

  testWidgets('direction reverses for the opposite switch', (tester) async {
    await tester.pumpWidget(harness(currentIndex: 1));
    await tester.pumpWidget(harness(currentIndex: 0));

    // songs → home is towardsAbove: new page arrives from above (-), old
    // page pushed down (+).
    await tester.pump(const Duration(milliseconds: 100));
    expect(dyOf(tester, 'A:0'), lessThan(0));
    expect(dyOf(tester, 'B:0'), greaterThan(0));
  });

  testWidgets('reduced motion only fades, with no translation', (
    tester,
  ) async {
    await tester.pumpWidget(harness(currentIndex: 0, reducedMotion: true));
    await tester.pumpWidget(harness(currentIndex: 1, reducedMotion: true));

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('A:0'), findsOneWidget);
    expect(find.text('B:0'), findsOneWidget);
    expect(dyOf(tester, 'A:0'), 0);
    expect(dyOf(tester, 'B:0'), 0);

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('A:0'), findsNothing);
    expect(find.text('B:0'), findsOneWidget);
  });

  testWidgets(
    'switching again mid-transition never shows more than two branches '
    'onstage, and drops the oldest one at once',
    (tester) async {
      await tester.pumpWidget(harness(currentIndex: 0));
      await tester.pumpWidget(harness(currentIndex: 1));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(harness(currentIndex: 2));
      await tester.pump(const Duration(milliseconds: 50));

      final onstage = ['A:0', 'B:0', 'C:0'].where(
        (text) => find.text(text).evaluate().isNotEmpty,
      );
      expect(onstage.length, lessThanOrEqualTo(2));
      expect(
        find.text('A:0'),
        findsNothing,
        reason: 'dropped the moment songs → albums started',
      );
      expect(find.text('B:0'), findsOneWidget);
      expect(find.text('C:0'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('B:0'), findsNothing);
      expect(find.text('C:0'), findsOneWidget);
    },
  );

  testWidgets('a hidden branch has its TickerMode disabled', (tester) async {
    await tester.pumpWidget(harness(currentIndex: 0));

    final tickerModes = find
        .ancestor(
          of: find.text('B:0', skipOffstage: false),
          matching: find.byType(TickerMode, skipOffstage: false),
        )
        .evaluate()
        .map((element) => element.widget as TickerMode);
    expect(tickerModes.map((t) => t.enabled), contains(isFalse));
  });

  testWidgets('a branch keeps its state across a switch away and back', (
    tester,
  ) async {
    await tester.pumpWidget(harness(currentIndex: 0));
    await tester.tap(find.text('A:0'));
    await tester.pump();
    expect(find.text('A:1'), findsOneWidget);

    await tester.pumpWidget(harness(currentIndex: 1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(harness(currentIndex: 0));
    await tester.pumpAndSettle();

    expect(find.text('A:1'), findsOneWidget);
  });

  testWidgets('switching to the already-current branch does not animate', (
    tester,
  ) async {
    await tester.pumpWidget(harness(currentIndex: 1));
    await tester.pumpAndSettle();

    await tester.pumpWidget(harness(currentIndex: 1));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('B:0'), findsOneWidget);
    expect(dyOf(tester, 'B:0'), 0);
    expect(
      find.text('A:0'),
      findsNothing,
      reason: 'no transition started, so the other branch never came onstage',
    );
  });
}
