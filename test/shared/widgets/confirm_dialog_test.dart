import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/confirm_dialog.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<Future<bool>> open(
    WidgetTester tester, {
    bool destructive = true,
    String? body,
  }) async {
    late Future<bool> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = confirmAction(
              context,
              title: 'Delete it?',
              body: body,
              confirmLabel: 'Delete',
              destructive: destructive,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('confirm answers true, cancel answers false', (tester) async {
    var result = await open(tester, body: 'Gone for good.');
    expect(find.text('Gone for good.'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);

    result = await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('dismissing counts as no', (tester) async {
    final result = await open(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('only a destructive dialog colours the confirm button', (
    tester,
  ) async {
    await open(tester);
    final context = tester.element(find.text('Delete'));
    final error = Theme.of(context).colorScheme.error;
    FilledButton button() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Delete'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button().style?.backgroundColor?.resolve({}), error);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    await open(tester, destructive: false);
    expect(button().style, isNull);
  });
}
