import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/song_row_view.dart';
import 'package:material_ui/material_ui.dart';

Widget _row({Widget? more}) => MaterialApp(
  home: Scaffold(
    body: SongRowView(
      title: 'Title',
      heart: const Icon(AppIcons.favorite, key: ValueKey('heart')),
      more: more,
      onTap: () {},
    ),
  ),
);

void main() {
  const moreKey = ValueKey('more');
  Finder opacity() =>
      find.ancestor(of: find.byKey(moreKey), matching: find.byType(Opacity));

  testWidgets('the more slot sits after the heart', (tester) async {
    await tester.pumpWidget(
      _row(more: const SizedBox(key: moreKey, width: 36, height: 36)),
    );

    final heart = tester.getTopLeft(find.byKey(const ValueKey('heart'))).dx;
    final more = tester.getTopLeft(find.byKey(moreKey)).dx;
    expect(more, greaterThan(heart));
  });

  testWidgets('without a more slot there is nothing extra', (tester) async {
    await tester.pumpWidget(_row());
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('the more slot is dimmer at rest and full on hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      _row(more: const SizedBox(key: moreKey, width: 36, height: 36)),
    );
    expect(tester.widget<Opacity>(opacity().first).opacity, lessThan(1));
    // Dimmed, but still drawn and hit-testable: it is always visible.
    expect(tester.widget<Opacity>(opacity().first).opacity, greaterThan(0.4));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.text('Title')));
    await tester.pump();

    expect(tester.widget<Opacity>(opacity().first).opacity, 1);
  });
}
