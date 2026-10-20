import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/min_busy_builder.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps a [MinBusyBuilder] showing 'busy' or 'idle'.
Future<void> pumpBusy(WidgetTester tester, bool busy) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: MinBusyBuilder(
      busy: busy,
      builder: (_, busy) => Text(busy ? 'busy' : 'idle'),
    ),
  ),
);

void main() {
  testWidgets('starts idle, turns busy at once', (tester) async {
    await pumpBusy(tester, false);
    expect(find.text('idle'), findsOneWidget);

    await pumpBusy(tester, true);
    expect(find.text('busy'), findsOneWidget);
  });

  testWidgets('a short task stays busy until 300 ms, then idle at once', (
    tester,
  ) async {
    await pumpBusy(tester, false);
    await pumpBusy(tester, true);
    await tester.pump(const Duration(milliseconds: 50));
    await pumpBusy(tester, false);
    expect(find.text('busy'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 249));
    expect(find.text('busy'), findsOneWidget, reason: 'at 299 ms');

    await tester.pump(const Duration(milliseconds: 2));
    expect(find.text('idle'), findsOneWidget, reason: 'at 301 ms');
  });

  testWidgets('a long task turns idle as soon as it ends', (tester) async {
    await pumpBusy(tester, true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('busy'), findsOneWidget);

    await pumpBusy(tester, false);
    expect(find.text('idle'), findsOneWidget);
  });

  testWidgets('busy again during the hold starts a new minimum', (
    tester,
  ) async {
    await pumpBusy(tester, true);
    await pumpBusy(tester, false);
    await tester.pump(const Duration(milliseconds: 200));
    await pumpBusy(tester, true);
    await tester.pump(const Duration(milliseconds: 50));
    await pumpBusy(tester, false);

    // 301 ms after the first start, 101 ms after the second.
    await tester.pump(const Duration(milliseconds: 51));
    expect(find.text('busy'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 198));
    expect(find.text('busy'), findsOneWidget, reason: '299 ms after');
    await tester.pump(const Duration(milliseconds: 2));
    expect(find.text('idle'), findsOneWidget, reason: '301 ms after');
  });

  testWidgets('disposing during the hold cancels its timer', (tester) async {
    await pumpBusy(tester, true);
    await pumpBusy(tester, false);
    await tester.pumpWidget(const SizedBox());
    // A pending timer would fail the test here.
    await tester.pump(const Duration(milliseconds: 400));
  });
}
