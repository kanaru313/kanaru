import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/top_bar.dart';
import 'package:kanaru/app/shell/top_bar_search_field.dart';
import 'package:kanaru/app/shell/window/desktop_window.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/features/library/widgets/library_rescan_button.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../core/indexer/scripted_indexer.dart';
import '../features/library/browse_test_data.dart';
import '../features/library/library_test_harness.dart';

void main() {
  final rescan = find.descendant(
    of: find.byType(TopBar),
    matching: find.byType(LibraryRescanButton),
  );

  Future<void> pumpAt(
    WidgetTester tester,
    LibraryHarness h,
    double width, {
    bool hasRoots = true,
  }) async {
    await h.pump(tester, hasRoots: hasRoots);
    tester.view.physicalSize = Size(width, 800);
    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();
    expect(find.byType(TopBar), findsOneWidget);
  }

  for (final width in [400.0, 1200.0]) {
    testWidgets('is in the top bar at $width px, left of Settings', (
      tester,
    ) async {
      final h = LibraryHarness();
      await pumpAt(tester, h, width);

      expect(rescan, findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow');
      final settings = find.descendant(
        of: find.byType(TopBar),
        matching: find.widgetWithIcon(IconButton, AppIcons.settingsOutlined),
      );
      expect(
        tester.getTopRight(rescan).dx,
        lessThanOrEqualTo(tester.getTopLeft(settings).dx),
      );
      expect(tester.getSize(rescan), tester.getSize(settings));
      expect(tester.getTopLeft(rescan).dy, tester.getTopLeft(settings).dy);
    });
  }

  testWidgets('is absent without a music folder', (tester) async {
    final h = LibraryHarness();
    await pumpAt(tester, h, 1200, hasRoots: false);
    expect(rescan, findsNothing);
  });

  testWidgets('is absent without a library database', (tester) async {
    final h = LibraryHarness(hasDatabase: false);
    await pumpAt(tester, h, 1200);
    expect(rescan, findsNothing);
  });

  testWidgets('a tap starts a scan, then a disabled ring takes its place', (
    tester,
  ) async {
    final indexer = ScriptedIndexer();
    final h = LibraryHarness(
      overrides: [libraryIndexerProvider.overrideWith(() => indexer)],
    );
    await pumpAt(tester, h, 1200);
    final button = find.descendant(
      of: rescan,
      matching: find.byType(IconButton),
    );
    final ring = find.descendant(
      of: rescan,
      matching: find.byType(CircularProgressIndicator),
    );
    expect(ring, findsNothing);

    await tester.tap(button);
    expect(indexer.scans, 1);
    indexer.emit(
      const IndexerScanning(phase: ScanPhase.discovering, rootPath: '/m'),
    );
    await tester.pump();
    expect(ring, findsOneWidget);
    expect(tester.widget<IconButton>(button).onPressed, isNull);

    indexer.emit(IndexerFinished(const ScanSummary()));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(ring, findsNothing);
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);
  });

  testWidgets('at 480 px with window buttons the search field keeps 120 px '
      'or more and nothing overflows', (tester) async {
    final h = LibraryHarness(
      overrides: [customTitleBarProvider.overrideWithValue(true)],
    );
    await h.pump(tester, hasRoots: true);
    tester.view.physicalSize = const Size(480, 800);
    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'no overflow');
    expect(rescan, findsOneWidget);
    expect(
      tester.getSize(find.byType(TopBarSearchField)).width,
      greaterThanOrEqualTo(120),
    );
  });
}
