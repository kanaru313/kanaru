import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_dialog_frame.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_route.dart';
import 'package:kanaru/shared/widgets/context_modal/fade_edge_scroll_view.dart';
import 'package:material_ui/material_ui.dart';

Future<List<int>> _open(
  WidgetTester tester, {
  required int count,
  Size size = const Size(1000, 800),
  ScrollController? controller,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final built = <int>[];
  final page = ContextModalPage.lazy(
    key: 'lazy',
    itemCount: count,
    scrollController: controller,
    itemBuilder: (_, _, i) {
      built.add(i);
      return SizedBox(height: 40, child: Text('Row $i'));
    },
  );
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showContextModal<Object>(context, root: page),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return built;
}

void main() {
  testWidgets('a long lazy body builds only the rows near the viewport', (
    tester,
  ) async {
    final built = await _open(tester, count: 10000);
    expect(built.toSet().length, lessThan(60));
    expect(find.text('Row 0'), findsOneWidget);
    expect(find.text('Row 9999'), findsNothing);
  });

  testWidgets('the lazy body scrolls, fades its edge and hides the scrollbar', (
    tester,
  ) async {
    await _open(tester, count: 500);
    expect(find.byType(Scrollbar), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Row 0'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(FadeEdgeScrollView),
        matching: find.byType(ShaderMask),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a short lazy body wraps its rows, a long one fills the dialog', (
    tester,
  ) async {
    await _open(tester, count: 3);
    final dialog = find.descendant(
      of: find.byType(ContextModalDialogFrame),
      matching: find.byType(Material),
    );
    expect(tester.getSize(dialog.first).height, 120);
    expect(
      find.descendant(
        of: find.byType(FadeEdgeScrollView),
        matching: find.byType(ShaderMask),
      ),
      findsNothing,
    );
  });

  testWidgets('a long lazy body is capped at the dialog height', (
    tester,
  ) async {
    await _open(tester, count: 500, size: const Size(1000, 300));
    final dialog = find.descendant(
      of: find.byType(ContextModalDialogFrame),
      matching: find.byType(Material),
    );
    expect(tester.getSize(dialog.first).height, 300 - 48);
  });

  testWidgets('the page scroll controller drives the lazy body', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _open(tester, count: 500, controller: controller);
    controller.jumpTo(800);
    await tester.pumpAndSettle();
    expect(find.text('Row 20'), findsOneWidget);
    expect(find.text('Row 0'), findsNothing);
  });
}
