import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/features/library/library_route_keys.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:material_ui/material_ui.dart';

import 'browse_test_data.dart';
import 'library_test_harness.dart';

void main() {
  /// Opens [location] on a library whose root is a real folder with one
  /// song, so a rescan finds it.
  Future<void> openScannable(
    WidgetTester tester,
    LibraryHarness h,
    String location,
  ) async {
    final music = h.folder('music');
    h.touch(music, 'a.mp3');
    await tester.runAsync(() => h.db.addRoots([music], now: 1));
    await h.pump(tester, hasRoots: true);
    h.container.read(routerProvider).go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('the albums page rescans from its floating button, and the '
      'result is announced once', (tester) async {
    final h = LibraryHarness();
    await openScannable(tester, h, '/songs');
    // Songs stays mounted next to Albums: the result must still show once.
    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byTooltip('Rescan'));
    await settleIo(tester);

    expect(find.text('Scan complete'), findsOneWidget);
    // A second copy would be queued behind the first one.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Scan complete'), findsNothing);
  });

  testWidgets('every library page has the button, detail pages do not', (
    tester,
  ) async {
    final h = LibraryHarness();
    await openWithTracks(tester, h, const [
      TestTrack('one', artist: 'Ann', album: 'X'),
    ], location: '/songs');
    expect(find.byTooltip('Rescan'), findsOneWidget);

    for (final location in ['/albums', '/artists']) {
      goTo(tester, h, location);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Rescan'), findsOneWidget, reason: location);
    }

    goTo(tester, h, albumLocation(const AlbumKey('ann', 'x')));
    await tester.pumpAndSettle();
    expect(find.text('X'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsNothing);

    goTo(tester, h, artistLocation('ann'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('no button without a music folder', (tester) async {
    final h = LibraryHarness();
    await h.pump(tester);
    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  group('settings', () {
    Finder rescanLibrary() => find.widgetWithText(FilledButton, 'Rescan');

    testWidgets('Library > Rescan library scans and announces it', (
      tester,
    ) async {
      final h = LibraryHarness();
      await openScannable(tester, h, '/settings');

      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Rescan library'), findsOneWidget);
      final library = tester.getTopLeft(find.text('Library')).dy;
      expect(
        library,
        lessThan(tester.getTopLeft(find.text('Appearance')).dy),
        reason: 'Library comes before Appearance',
      );

      await tester.tap(rescanLibrary());
      await settleIo(tester);

      expect(find.text('Scan complete'), findsOneWidget);
      expect(tester.widget<FilledButton>(rescanLibrary()).onPressed, isNotNull);
    });

    testWidgets('the button is disabled without a music folder', (
      tester,
    ) async {
      final h = LibraryHarness();
      await h.pump(tester);
      goTo(tester, h, '/settings');
      await tester.pumpAndSettle();

      expect(find.text('Rescan library'), findsOneWidget);
      expect(tester.widget<FilledButton>(rescanLibrary()).onPressed, isNull);
    });
  });
}
