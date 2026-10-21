import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

void main() {
  Finder rescan() => find.widgetWithIcon(FloatingActionButton, Icons.refresh);
  Finder ring() => find.byType(CircularProgressIndicator);

  testWidgets('a ring beside the rescan button while covers are made', (
    tester,
  ) async {
    final h = LibraryHarness();
    await h.pump(tester, hasRoots: true);
    goTo(tester, h, '/songs');
    await tester.pumpAndSettle();
    expect(ring(), findsNothing);

    h.container.read(coverPassProvider.notifier).report(340, 1170);
    await tester.pump();
    expect(ring(), findsOneWidget);
    expect(find.byTooltip('Making covers… 340 / 1,170'), findsOneWidget);
    expect(
      tester.widget<FloatingActionButton>(rescan()).onPressed,
      isNotNull,
      reason: 'a rescan makes the cover pass yield',
    );

    h.container.read(coverPassProvider.notifier).finish();
    await tester.pump();
    expect(ring(), findsNothing);
  });

  testWidgets('settings show the ring and keep rescan enabled', (tester) async {
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
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);
  });
}
