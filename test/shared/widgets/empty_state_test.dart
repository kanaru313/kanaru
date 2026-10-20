import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/empty_state.dart';
import 'package:material_ui/material_ui.dart';

const _message =
    'Add a folder with music in it, and its songs, albums and artists '
    'show up here.';

Future<void> _pump(WidgetTester tester, Size size, double textScale) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: const EmptyState(
              icon: Icons.music_note_outlined,
              title: 'No music yet',
              message: _message,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('large text in a short space scrolls instead of overflowing', (
    tester,
  ) async {
    await _pump(tester, const Size(320, 180), 2);
    expect(tester.takeException(), isNull);

    final message = find.text(_message);
    expect(tester.getRect(message).bottom, greaterThan(180), reason: 'cut');
    await tester.drag(find.byType(EmptyState), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.getRect(message).bottom, lessThanOrEqualTo(180));
  });

  testWidgets('stays centered when it fits', (tester) async {
    const size = Size(600, 500);
    await _pump(tester, size, 1);
    expect(tester.takeException(), isNull);

    final top = tester.getRect(find.byType(Icon)).top;
    final bottom = tester.getRect(find.text(_message)).bottom;
    expect((top + bottom) / 2, moreOrLessEquals(size.height / 2, epsilon: 1));
    expect(
      tester.getCenter(find.text('No music yet')).dx,
      moreOrLessEquals(size.width / 2, epsilon: 1),
    );
  });

  testWidgets('takes its own height in an unbounded column', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState(icon: Icons.music_note_outlined, title: 'Empty'),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Empty'), findsOneWidget);
  });
}
