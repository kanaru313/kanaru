import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

void main() {
  Finder rescan() => find.widgetWithIcon(FloatingActionButton, Icons.refresh);
  Finder ring() => find.byType(CircularProgressIndicator);

  testWidgets('the rescan button turns into a disabled ring while covers '
      'are made', (tester) async {
    final h = LibraryHarness();
    await h.pump(tester, hasRoots: true);
    goTo(tester, h, '/songs');
    await tester.pumpAndSettle();
    expect(ring(), findsNothing);

    h.container.read(coverPassProvider.notifier).report(340, 1170);
    await tester.pump();
    final fab = find.byType(FloatingActionButton);
    expect(find.descendant(of: fab, matching: ring()), findsOneWidget);
    expect(rescan(), findsNothing);
    expect(find.byTooltip('Making covers… 340 / 1,170'), findsOneWidget);
    expect(tester.widget<FloatingActionButton>(fab).onPressed, isNull);

    h.container.read(coverPassProvider.notifier).finish();
    await tester.pump();
    expect(ring(), findsNothing);
    expect(tester.widget<FloatingActionButton>(rescan()).onPressed, isNotNull);
  });

  testWidgets('settings show the ring and disable rescan', (tester) async {
    final h = LibraryHarness();
    await h.pump(tester, hasRoots: true);
    goTo(tester, h, '/settings');
    await tester.pumpAndSettle();

    h.container.read(coverPassProvider.notifier).report(1, 4);
    await tester.pump();
    expect(find.byTooltip('Making covers… 1 / 4'), findsOneWidget);
    final button = find.ancestor(
      of: find.text('Rescan'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);

    h.container.read(coverPassProvider.notifier).finish();
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);
  });
}
