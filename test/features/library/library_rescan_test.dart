import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/features/library/library_route_keys.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/scripted_indexer.dart';
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

  testWidgets('a quick scan keeps the ring for 300 ms, a long one shows '
      'its progress', (tester) async {
    final indexer = ScriptedIndexer();
    final h = LibraryHarness(
      overrides: [libraryIndexerProvider.overrideWith(() => indexer)],
    );
    await h.pump(tester, hasRoots: true);
    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();
    FloatingActionButton fab() =>
        tester.widget(find.byType(FloatingActionButton));
    final ring = find.descendant(
      of: find.byType(FloatingActionButton),
      matching: find.byType(CircularProgressIndicator),
    );

    await tester.tap(find.byTooltip('Rescan'));
    expect(indexer.scans, 1);

    indexer.emit(
      const IndexerScanning(phase: ScanPhase.discovering, rootPath: '/m'),
    );
    await tester.pump();
    expect(ring, findsOneWidget);
    expect(fab().onPressed, isNull);

    await tester.pump(const Duration(milliseconds: 50));
    indexer.emit(IndexerFinished(const ScanSummary()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 249));
    expect(ring, findsOneWidget, reason: 'at 299 ms');
    expect(fab().onPressed, isNull, reason: 'disabled during the hold');

    await tester.pump(const Duration(milliseconds: 2));
    expect(ring, findsNothing, reason: 'at 301 ms');
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(fab().onPressed, isNotNull);

    indexer.emit(
      const IndexerScanning(
        phase: ScanPhase.reading,
        rootPath: '/m',
        done: 1,
        total: 4,
      ),
    );
    await tester.pump();
    expect(tester.widget<CircularProgressIndicator>(ring).value, 0.25);
    await tester.pump(const Duration(milliseconds: 500));
    indexer.emit(IndexerFinished(const ScanSummary()));
    await tester.pump();
    expect(ring, findsNothing, reason: 'a long scan ends at once');
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('during the 300 ms hold the button keeps the last progress '
      'the scan reported; the next scan starts from its own', (tester) async {
    final indexer = ScriptedIndexer();
    final h = LibraryHarness(
      overrides: [libraryIndexerProvider.overrideWith(() => indexer)],
    );
    await h.pump(tester, hasRoots: true);
    goTo(tester, h, '/albums');
    await tester.pumpAndSettle();
    final ring = find.descendant(
      of: find.byType(FloatingActionButton),
      matching: find.byType(CircularProgressIndicator),
    );

    await tester.tap(find.byTooltip('Rescan'));
    indexer.emit(
      const IndexerScanning(phase: ScanPhase.discovering, rootPath: '/m'),
    );
    await tester.pump();
    expect(find.byTooltip('Looking for music files…'), findsOneWidget);

    indexer.emit(
      const IndexerScanning(
        phase: ScanPhase.reading,
        rootPath: '/m',
        done: 3,
        total: 4,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    indexer.emit(IndexerFinished(const ScanSummary()));
    await tester.pump();
    expect(ring, findsOneWidget, reason: 'held');
    expect(find.byTooltip('Reading tags 3 / 4'), findsOneWidget);
    expect(find.byTooltip('Looking for music files…'), findsNothing);
    expect(tester.widget<CircularProgressIndicator>(ring).value, 0.75);

    await tester.pump(const Duration(milliseconds: 300));
    expect(ring, findsNothing);
    expect(find.byTooltip('Rescan'), findsOneWidget);

    // The next scan shows its own progress from its first frame, not the
    // last one of the scan before.
    await tester.tap(find.byTooltip('Rescan'));
    expect(indexer.scans, 2);
    indexer.emit(
      const IndexerScanning(phase: ScanPhase.discovering, rootPath: '/m'),
    );
    await tester.pump();
    expect(find.byTooltip('Looking for music files…'), findsOneWidget);
    expect(find.byTooltip('Reading tags 3 / 4'), findsNothing);
    expect(tester.widget<CircularProgressIndicator>(ring).value, isNull);

    indexer.emit(
      const IndexerScanning(
        phase: ScanPhase.reading,
        rootPath: '/m',
        done: 1,
        total: 2,
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Reading tags 1 / 2'), findsOneWidget);
    expect(tester.widget<CircularProgressIndicator>(ring).value, 0.5);
    indexer.emit(IndexerFinished(const ScanSummary()));
    await tester.pumpAndSettle(const Duration(seconds: 1));
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

    for (final width in [1280.0, 480.0]) {
      testWidgets('at $width px, scanning turns the icon into a progress '
          'ring without resizing the button, kept for 300 ms', (tester) async {
        final indexer = ScriptedIndexer();
        final h = LibraryHarness(
          overrides: [libraryIndexerProvider.overrideWith(() => indexer)],
        );
        await h.pump(tester, hasRoots: true);
        tester.view.physicalSize = Size(width, 800);
        goTo(tester, h, '/settings');
        await tester.pumpAndSettle();
        final button = rescanLibrary();
        final idle = tester.getRect(button);
        final ring = find.descendant(
          of: button,
          matching: find.byType(CircularProgressIndicator),
        );
        final icon = find.descendant(
          of: button,
          matching: find.byIcon(Icons.refresh),
        );
        expect(ring, findsNothing);
        expect(icon, findsOneWidget);

        await tester.tap(button);
        expect(indexer.scans, 1);
        indexer.emit(
          const IndexerScanning(phase: ScanPhase.discovering, rootPath: '/m'),
        );
        await tester.pump();
        expect(ring, findsOneWidget);
        expect(tester.widget<CircularProgressIndicator>(ring).value, isNull);
        expect(icon, findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byTooltip('Looking for music files…'), findsOneWidget);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        expect(tester.getRect(button), idle);

        indexer.emit(
          const IndexerScanning(
            phase: ScanPhase.reading,
            rootPath: '/m',
            done: 1,
            total: 4,
          ),
        );
        await tester.pump();
        expect(tester.widget<CircularProgressIndicator>(ring).value, 0.25);
        expect(find.byTooltip('Reading tags 1 / 4'), findsOneWidget);
        expect(tester.getRect(button), idle);

        indexer.emit(IndexerFinished(const ScanSummary()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 299));
        expect(ring, findsOneWidget, reason: 'held until 300 ms');
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        // The scan is over: the hold shows its last progress, not the
        // first step's text.
        expect(find.byTooltip('Reading tags 1 / 4'), findsOneWidget);
        expect(find.byTooltip('Looking for music files…'), findsNothing);
        expect(tester.widget<CircularProgressIndicator>(ring).value, 0.25);

        await tester.pump(const Duration(milliseconds: 2));
        expect(ring, findsNothing, reason: 'off at once after 300 ms');
        expect(icon, findsOneWidget);
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(tester.getRect(button), idle);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      });
    }

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
