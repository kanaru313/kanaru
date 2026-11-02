import 'package:flutter_test/flutter_test.dart';

/// Lets a context modal's database reads (links, favorite, counts) finish
/// and its animations end. A plain `pumpAndSettle` cannot wait for real I/O.
/// The last pump drains the zero-delay timer a disposed database stream
/// leaves behind.
Future<void> settleModal(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 100));
}
