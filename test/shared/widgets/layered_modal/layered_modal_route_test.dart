import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_dialog_frame.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_sheet_frame.dart';
import 'package:kanaru/shared/widgets/layered_modal/layered_modal_route.dart';
import 'package:material_ui/material_ui.dart';

class _StatefulCounter extends StatefulWidget {
  const _StatefulCounter();
  @override
  State<_StatefulCounter> createState() => _StatefulCounterState();
}

class _StatefulCounterState extends State<_StatefulCounter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('Count: $count'),
  );
}

Future<void> _pumpHost(
  WidgetTester tester, {
  Size size = const Size(1000, 800),
  bool disableAnimations = false,
  FocusNode? parentButtonFocus,
  bool tallGrandchild = false,
  String? parentLabel,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLayeredModal<void>(
              context,
              semanticLabel: parentLabel,
              builder: (parentCtx) => LayeredModalBody(
                header: const Text('Parent header'),
                footer: const Text('Parent footer'),
                children: [
                  const Text('Parent body text'),
                  const _StatefulCounter(),
                  TextButton(
                    focusNode: parentButtonFocus,
                    onPressed: () => showLayeredModal<void>(
                      parentCtx,
                      builder: (childCtx) => LayeredModalBody(
                        header: const LayeredModalTopBar(title: 'Child modal'),
                        children: [
                          const Text('Child body text'),
                          TextButton(
                            autofocus: true,
                            onPressed: () => showLayeredModal<void>(
                              childCtx,
                              builder: (_) => LayeredModalBody(
                                header: const LayeredModalTopBar(
                                  title: 'Grandchild',
                                ),
                                children: [
                                  const Text('Grandchild body'),
                                  if (tallGrandchild)
                                    const SizedBox(height: 2000),
                                ],
                              ),
                            ),
                            child: const Text('Open grandchild'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text('Open child'),
                  ),
                ],
              ),
            ),
            child: const Text('Open parent'),
          ),
        ),
      ),
    ),
  );
}

Finder _materialIn(Finder frame) =>
    find.descendant(of: frame, matching: find.byType(Material)).first;

void main() {
  testWidgets('width 1000 uses a 400 px dialog; width 500 uses a sheet', (
    tester,
  ) async {
    await _pumpHost(tester, size: const Size(1000, 800));
    await tester.tap(find.text('Open parent'));
    await tester.pumpAndSettle();
    final dialogFrame = find.byType(ContextModalDialogFrame);
    expect(dialogFrame, findsOneWidget);
    expect(tester.getSize(_materialIn(dialogFrame)).width, 400);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await _pumpHost(tester, size: const Size(500, 800));
    await tester.tap(find.text('Open parent'));
    await tester.pumpAndSettle();
    expect(find.byType(ContextModalSheetFrame), findsOneWidget);
    expect(find.byType(ContextModalDialogFrame), findsNothing);
  });

  testWidgets('child and grandchild modals stack with narrower shifted cards', (
    tester,
  ) async {
    await _pumpHost(tester, size: const Size(1000, 800));
    await tester.tap(find.text('Open parent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();

    expect(find.text('Parent header'), findsOneWidget);
    expect(find.text('Parent body text'), findsOneWidget);
    expect(find.text('Child modal'), findsOneWidget);

    final parentMat = _materialIn(find.byType(ContextModalDialogFrame));
    final childMat = _materialIn(find.byType(LayeredModalChildFrame));
    expect(tester.getSize(childMat).width, 360);
    expect(
      tester.getTopLeft(childMat).dy,
      greaterThan(tester.getTopLeft(parentMat).dy),
    );

    await tester.tap(find.text('Open grandchild'));
    await tester.pumpAndSettle();
    final childFrames = find.byType(LayeredModalChildFrame);
    expect(childFrames, findsNWidgets(2));
    final grandMat = _materialIn(childFrames.last);
    expect(tester.getSize(grandMat).width, 330);
    expect(
      tester.getTopLeft(grandMat).dy,
      greaterThan(tester.getTopLeft(childMat).dy),
    );
  });

  testWidgets('Esc, scrim tap and close button close only the child first', (
    tester,
  ) async {
    await _pumpHost(tester);
    await tester.tap(find.text('Open parent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Child modal'), findsNothing);
    expect(find.text('Parent body text'), findsOneWidget);

    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Child modal'), findsNothing);
    expect(find.text('Parent body text'), findsOneWidget);

    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Child modal'), findsNothing);
    expect(find.text('Parent body text'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Parent body text'), findsNothing);
  });

  testWidgets(
    'resizing 1000 to 500 switches to sheet and preserves state; reduced motion is instant; focus restores on child close',
    (tester) async {
      final parentFocus = FocusNode(debugLabel: 'ParentOpenChild');
      addTearDown(parentFocus.dispose);
      await _pumpHost(
        tester,
        size: const Size(1000, 800),
        disableAnimations: true,
        parentButtonFocus: parentFocus,
      );
      await tester.tap(find.text('Open parent'));
      await tester.pump();
      expect(
        find.ancestor(
          of: find.byType(ContextModalDialogFrame),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Count: 0'));
      await tester.pump();

      parentFocus.requestFocus();
      await tester.pump();
      expect(parentFocus.hasFocus, isTrue);

      await tester.tap(find.text('Open child'));
      await tester.pump();
      expect(parentFocus.hasFocus, isFalse);
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.ancestor(
          of: find.byElementPredicate((e) => e == focused),
          matching: find.byType(LayeredModalChildFrame),
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(parentFocus.hasFocus, isTrue);

      tester.view.physicalSize = const Size(500, 800);
      await tester.pump();
      expect(find.byType(ContextModalSheetFrame), findsOneWidget);
      expect(find.text('Count: 1'), findsOneWidget);
    },
  );
  testWidgets('depth 2 dialog stays inside a short window', (tester) async {
    await _pumpHost(tester, size: const Size(1000, 560), tallGrandchild: true);
    await tester.tap(find.text('Open parent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open grandchild'));
    await tester.pumpAndSettle();

    final grand = _materialIn(find.byType(LayeredModalChildFrame).last);
    final rect = tester.getRect(grand);
    expect(rect.bottom, lessThanOrEqualTo(560 - 24 + 0.01));
    expect(rect.top, greaterThanOrEqualTo(0));
  });

  testWidgets('a child opened in a narrow window is a 72% sheet', (
    tester,
  ) async {
    await _pumpHost(tester, size: const Size(500, 800), tallGrandchild: true);
    await tester.tap(find.text('Open parent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open grandchild'));
    await tester.pumpAndSettle();

    final childFrames = find.byType(LayeredModalChildFrame);
    expect(childFrames, findsNWidgets(2));
    final grand = tester.widget<LayeredModalChildFrame>(childFrames.last);
    expect(grand.isSheet, isTrue);
    final sheet = find.descendant(
      of: childFrames.last,
      matching: find.byType(ContextModalSheetFrame),
    );
    expect(sheet, findsOneWidget);
    final size = tester.getSize(_materialIn(sheet));
    expect(size.height, closeTo(800 * 0.72, 1));
    expect(size.width, 500);
    expect(
      tester.widget<Material>(_materialIn(sheet)).color,
      Theme.of(tester.element(sheet)).colorScheme.surfaceContainerHighest,
    );
  });

  testWidgets('semantic label names the modal route', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpHost(tester, parentLabel: 'Pick a language');
    await tester.tap(find.text('Open parent'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Pick a language'), findsOneWidget);
    handle.dispose();
  });
}
