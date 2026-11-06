import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/layered_modal/layered_modal_stack.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('pops the modal and the dialogs above it, not the page', (
    tester,
  ) async {
    late BuildContext parentContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) {
                  parentContext = dialogContext;
                  return Builder(
                    builder: (c) => TextButton(
                      onPressed: () => showDialog<void>(
                        context: c,
                        builder: (_) => const Text('child'),
                      ),
                      child: const Text('open child'),
                    ),
                  );
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open child'));
    await tester.pumpAndSettle();
    expect(find.text('child'), findsOneWidget);

    closeLayeredModalStack(parentContext);
    await tester.pumpAndSettle();
    expect(find.text('child'), findsNothing);
    expect(find.text('open child'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('does nothing for a context inside a page route', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Text('page');
          },
        ),
      ),
    );
    closeLayeredModalStack(pageContext);
    await tester.pumpAndSettle();
    expect(find.text('page'), findsOneWidget);
  });
}
