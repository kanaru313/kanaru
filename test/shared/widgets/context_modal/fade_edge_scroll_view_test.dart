import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/widgets/context_modal/fade_edge_scroll_view.dart';

Widget _app(int count, ScrollController? c) => Directionality(
  textDirection: TextDirection.ltr,
  child: SizedBox(
    height: 200,
    width: 200,
    child: FadeEdgeScrollView(
      controller: c,
      builder: (controller) => ListView(
        controller: controller,
        children: [
          for (var i = 0; i < count; i++)
            SizedBox(height: 50, child: Text('r$i')),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('no mask while everything fits', (tester) async {
    await tester.pumpWidget(_app(3, null));
    await tester.pump();
    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('mask appears when scrollable and keeps scroll position', (
    tester,
  ) async {
    final c = ScrollController();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(20, c));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ShaderMask), findsOneWidget);

    c.jumpTo(100);
    await tester.pump();
    await tester.pump();
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(c.offset, 100);

    c.jumpTo(c.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(c.offset, c.position.maxScrollExtent);
  });

  test('gradient fades only the requested ends', () {
    final top = fadeEdgeGradient(fadeStart: true, fadeEnd: false, length: 280);
    expect(top.colors.first.a, 0);
    expect(top.colors.last.a, 1);
    final bottom = fadeEdgeGradient(
      fadeStart: false,
      fadeEnd: true,
      length: 280,
    );
    expect(bottom.colors.first.a, 1);
    expect(bottom.colors.last.a, 0);
    final both = fadeEdgeGradient(fadeStart: true, fadeEnd: true, length: 280);
    expect(both.colors.length, 4);
    expect(both.stops, [0, 0.1, 0.9, 1]);
  });
}
