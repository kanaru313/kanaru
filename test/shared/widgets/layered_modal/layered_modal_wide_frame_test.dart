import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/layered_modal/layered_modal_route.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const contentKey = Key('wide');
  const childKey = Key('child');

  Future<void> pumpOpener(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLayeredModal<void>(
              context,
              builder: (parent) => TextButton(
                onPressed: () => showLayeredModal<void>(
                  parent,
                  wide: true,
                  builder: (_) =>
                      const SizedBox(key: childKey, width: 840, height: 500),
                ),
                child: const Text('child'),
              ),
            ),
            child: const Text('parent'),
          ),
        ),
      ),
    );
  }

  testWidgets('a top-level wide modal is sized by its content and centered', (
    tester,
  ) async {
    await pumpOpener(tester);
    final context = tester.element(find.text('parent'));
    showLayeredModal<void>(
      context,
      wide: true,
      builder: (_) => const SizedBox(key: contentKey, width: 840, height: 500),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(contentKey)), const Size(840, 500));
    expect(tester.getCenter(find.byKey(contentKey)), const Offset(640, 450));
    final scrims = tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .where((b) => b.color != null)
        .map((b) => b.color!.a);
    expect(scrims.last, closeTo(0.45, 0.01));
  });

  testWidgets('stacked over a modal it sits 28 px lower with a lighter scrim', (
    tester,
  ) async {
    await pumpOpener(tester);
    await tester.tap(find.text('parent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('child'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(childKey)), const Size(840, 500));
    expect(tester.getCenter(find.byKey(childKey)), const Offset(640, 478));
    final barriers = tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .where((b) => b.color != null)
        .map((b) => b.color!.a)
        .toList();
    expect(barriers.last, closeTo(0.35, 0.01));
  });
}
