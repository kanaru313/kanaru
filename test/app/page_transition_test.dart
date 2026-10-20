import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  /// Shows a page, then pushes a detail page over it.
  Future<void> pushDetail(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: buildTheme(null, Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const Text('list'),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('detail')),
    );
  }

  /// Transitions wrapping the page showing [text].
  Iterable<T> transitionsOfPage<T extends Widget>(
    WidgetTester tester,
    String text,
  ) => tester.widgetList<T>(
    find.ancestor(of: find.text(text), matching: find.byType(T)),
  );

  /// Transitions wrapping the pushed page (not the page below it).
  Iterable<T> transitionsOfDetail<T extends Widget>(WidgetTester tester) =>
      transitionsOfPage<T>(tester, 'detail');

  /// Colour painted behind the pushed page.
  Color detailBackground(WidgetTester tester) => tester
      .widgetList<ColoredBox>(
        find.ancestor(
          of: find.text('detail'),
          matching: find.byType(ColoredBox),
        ),
      )
      .first
      .color;

  testWidgets('a pushed page slides up and fades in', (tester) async {
    await pushDetail(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final slide = transitionsOfDetail<SlideTransition>(tester).single;
    expect(slide.position.value.dx, 0);
    expect(slide.position.value.dy, inExclusiveRange(0, 0.08));
    final fade = transitionsOfDetail<FadeTransition>(tester).single;
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    // The page below does not move nor fade.
    expect(
      transitionsOfPage<SlideTransition>(tester, 'list').single.position.value,
      Offset.zero,
    );
    expect(
      transitionsOfPage<FadeTransition>(tester, 'list').single.opacity.value,
      1,
    );

    // Opaque while moving, so the page below never shows through.
    expect(detailBackground(tester).a, 1);

    // Done once the 300 ms have run (on the next frame), then the surface
    // goes away so ink stays visible.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(
      transitionsOfDetail<SlideTransition>(tester).single.position.value,
      Offset.zero,
    );
    expect(detailBackground(tester), Colors.transparent);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a popped page slides down and fades out', (tester) async {
    await pushDetail(tester);
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final slide = transitionsOfDetail<SlideTransition>(tester).single;
    expect(slide.position.value.dy, inExclusiveRange(0, 0.08));
    // Gone once the 220 ms have run (removed on the next frame).
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('detail'), findsNothing);
  });

  testWidgets('with reduced motion a pushed page only fades', (tester) async {
    await pushDetail(tester, reduceMotion: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(transitionsOfDetail<SlideTransition>(tester), isEmpty);
    expect(
      transitionsOfDetail<FadeTransition>(tester).single.opacity.value,
      inExclusiveRange(0, 1),
    );
  });
}
