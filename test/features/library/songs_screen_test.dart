import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/core/indexer/tag_reader.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/library/songs/song_tile.dart';
import 'package:kanaru/features/library/songs/songs_list_provider.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/fake_tag_reader.dart';
import 'browse_test_data.dart';
import 'library_test_harness.dart';

/// A tag reader that waits for [release] so a test can look at a scan in
/// progress.
class _GatedTagReader extends FakeTagReader {
  final release = Completer<void>();

  @override
  Future<List<TrackTags>> readBatch(List<String> paths) async {
    await release.future;
    return super.readBatch(paths);
  }
}

void main() {
  /// Opens Songs on a library that already has [folder] as its root.
  Future<void> openSongs(
    WidgetTester tester,
    LibraryHarness h, {
    required String folder,
  }) async {
    await tester.runAsync(() => h.db.addRoots([folder], now: 1));
    await h.pump(tester, hasRoots: true);
    h.container.read(routerProvider).go('/songs');
    await tester.pumpAndSettle();
  }

  Finder rescan() => find.byTooltip('Rescan');

  /// The floating rescan button, whatever its state.
  FloatingActionButton rescanButton(WidgetTester tester) =>
      tester.widget(find.byType(FloatingActionButton));

  Future<void> scan(WidgetTester tester, LibraryHarness h) async {
    await tester.tap(rescan());
    await settleIo(tester, h);
  }

  testWidgets('lists scanned songs in title order and plays from the tap', (
    tester,
  ) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    h.touch(music, 'b.mp3');
    h.touch(music, 'a.mp3');
    await openSongs(tester, h, folder: music);
    await scan(tester, h);

    final a = tester.getTopLeft(find.text('A.MP3'));
    final b = tester.getTopLeft(find.text('B.MP3'));
    expect(a.dy, lessThan(b.dy));
    expect(find.text('Artist'), findsNWidgets(2));
    expect(find.text('0:01'), findsNWidgets(2));
    expect(
      find.text('Scan complete'),
      findsOneWidget,
      reason: 'the finished scan is announced',
    );
    expect(
      find.text('2 new'),
      findsOneWidget,
      reason: 'zero counts are left out',
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.text('B.MP3'));
    await tester.pump();
    final queue = h.container.read(playerServiceProvider).queue;
    expect([for (final t in queue.original) t.title], ['A.MP3', 'B.MP3']);
    expect(queue.current?.title, 'B.MP3');
    expect(h.backend.calls.any((c) => c.startsWith('open(B.MP3')), isTrue);
  });

  testWidgets('the rescan button shows progress and is disabled meanwhile', (
    tester,
  ) async {
    final gated = _GatedTagReader();
    final h = LibraryHarness(reader: gated);
    final music = h.folder('music');
    h.touch(music, 'a.mp3');
    await openSongs(tester, h, folder: music);
    await tester.tap(rescan());
    await waitForScanReading(tester, h);

    final ring = find.descendant(
      of: find.byType(FloatingActionButton),
      matching: find.byType(CircularProgressIndicator),
    );
    expect(ring, findsOneWidget);
    expect(
      tester.widget<CircularProgressIndicator>(ring).value,
      isNull,
      reason: 'spins until the first batch is read: a ring at 0 is empty',
    );
    expect(find.byTooltip('Reading tags 0 / 1'), findsOneWidget);
    expect(rescanButton(tester).onPressed, isNull);

    gated.release.complete();
    await settleIo(tester, h);
    expect(ring, findsNothing);
    expect(rescan(), findsOneWidget);
    expect(rescanButton(tester).onPressed, isNotNull);
  });

  testWidgets('reports a failed scan', (tester) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    h.touch(music, 'a.mp3');
    h.reader.throwOnRead = StateError('boom');
    await openSongs(tester, h, folder: music);
    await scan(tester, h);

    expect(find.text('Scan failed'), findsOneWidget);
    expect(
      find.text('See the log for details'),
      findsOneWidget,
      reason: 'the raw error stays in the log',
    );
    expect(find.textContaining('boom'), findsNothing);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
  });

  testWidgets('reports unreadable files and a root that was not found', (
    tester,
  ) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    h.touch(music, 'bad.mp3');
    final gone = '${h.tmp.resolveSymbolicLinksSync()}/gone';
    await tester.runAsync(() => h.db.addRoots([gone], now: 1));
    await openSongs(tester, h, folder: music);
    await scan(tester, h);

    expect(find.textContaining('1 file couldn\'t be read'), findsOneWidget);
    expect(find.textContaining('$gone was not found'), findsOneWidget);
    expect(find.text('Scan complete, with warnings'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('says so when the library is unavailable', (tester) async {
    final h = LibraryHarness(hasDatabase: false);
    await h.pump(tester);
    h.container.read(routerProvider).go('/songs');
    await tester.pumpAndSettle();

    expect(find.text('Couldn\'t open the library'), findsOneWidget);
    expect(rescan(), findsNothing);
  });

  testWidgets('without folders the button picks one and scans it', (
    tester,
  ) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    h.touch(music, 'a.mp3');
    h.picks.add(music);
    await h.pump(tester);
    h.container.read(routerProvider).go('/songs');
    await tester.pumpAndSettle();
    expect(find.text('Your library is empty'), findsOneWidget);

    await tester.tap(find.text('Choose music folder'));
    await settleIo(tester, h);

    expect((await tester.runAsync(h.db.roots))!.single.path, music);
    expect(find.text('A.MP3'), findsOneWidget);
    expect(find.text('Welcome to Kanaru'), findsNothing);
  });

  testWidgets('a refused folder is reported', (tester) async {
    final h = LibraryHarness();
    final missing = '${h.tmp.resolveSymbolicLinksSync()}/missing';
    h.picks.add(missing);
    await h.pump(tester);
    h.container.read(routerProvider).go('/songs');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose music folder'));
    await settleIo(tester, h);

    expect(find.text('$missing was not found'), findsOneWidget);
    expect(await tester.runAsync(h.db.roots), isEmpty);
  });

  testWidgets('folders without songs show the empty message', (tester) async {
    final h = LibraryHarness();
    await openSongs(tester, h, folder: h.folder('music'));

    expect(find.text('No songs found'), findsOneWidget);
    expect(rescan(), findsOneWidget);
  });

  testWidgets(
    'a scan that ends while the list is empty never shows the empty message '
    'before the new songs arrive, even with a long refresh interval',
    (tester) async {
      final gated = _GatedTagReader();
      final h = LibraryHarness(
        reader: gated,
        refreshInterval: const Duration(hours: 1),
      );
      final music = h.folder('music');
      h.touch(music, 'a.mp3');
      await openSongs(tester, h, folder: music);
      expect(find.text('No songs found'), findsOneWidget);

      await tester.tap(rescan());
      await tester.pump();
      gated.release.complete();
      await settleIo(
        tester,
        h,
        eachRound: (round) => expect(
          find.text('No songs found'),
          findsNothing,
          reason: 'round $round',
        ),
      );

      expect(find.text('A.MP3'), findsOneWidget);

      // The list's hour-long refresh timer must not outlive the test. Keep
      // the scope mounted: Riverpod disposes an unused autoDispose provider
      // through the mounted scope, and never if the scope itself is gone.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const SizedBox(),
        ),
      );
      await tester.pump();
      expect(h.container.exists(songsListProvider), isFalse);
    },
  );

  group('sort', () {
    /// 40 songs: titles s00..s39, durations falling as titles rise.
    final many = [
      for (var i = 0; i < 40; i++)
        TestTrack(
          's${i.toString().padLeft(2, '0')}',
          durationMs: (40 - i) * 1000,
        ),
    ];

    Future<void> chooseSort(
      WidgetTester tester,
      String current,
      String item,
    ) async {
      await tester.tap(find.widgetWithText(TextButton, current));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, item));
    }

    testWidgets(
      're-sorts, keeps rows meanwhile, saves and plays the new order',
      (tester) async {
        final h = LibraryHarness();
        await openWithTracks(tester, h, many, location: '/songs');
        expect(find.text('s00'), findsOneWidget);

        await tester.drag(find.text('s05'), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(find.text('s00'), findsNothing);

        await chooseSort(tester, 'Title', 'Duration');
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(SongTile), findsWidgets);
        await tester.pumpAndSettle();

        expect(
          h.container.read(settingsProvider).songSort,
          const SortChoice(SongSortField.duration),
        );
        // Shortest first, scrolled back to the top.
        expect(find.text('s39'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('s39')).dy,
          lessThan(tester.getTopLeft(find.text('s38')).dy),
        );

        await chooseSort(tester, 'Ascending', 'Descending');
        await tester.pumpAndSettle();
        expect(find.text('s00'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.tap(find.text('s01'));
        await tester.pump();
        final queue = h.container.read(playerServiceProvider).queue;
        expect(queue.original.take(3).map((t) => t.title), [
          's00',
          's01',
          's02',
        ]);
        expect(queue.current?.title, 's01');
      },
    );

    testWidgets('no spinner while the re-sorted list loads', (tester) async {
      // Each sort gets a stream the test feeds by hand.
      final streams = <StreamController<List<TrackListItem>>>[];
      final h = LibraryHarness(
        overrides: [
          songsListProvider.overrideWith((ref) {
            ref.watch(settingsProvider.select((s) => s.songSort));
            final controller = StreamController<List<TrackListItem>>();
            ref.onDispose(controller.close);
            streams.add(controller);
            return controller.stream;
          }),
        ],
      );
      TrackListItem item(String title) =>
          TrackListItem(id: title.hashCode, path: '/$title', title: title);
      await tester.runAsync(() => h.db.addRoots(['/m'], now: 1));
      await h.pump(tester, hasRoots: true);
      goTo(tester, h, '/songs');
      await tester.pump();
      streams.last.add([item('a'), item('b')]);
      await tester.pumpAndSettle();

      await chooseSort(tester, 'Title', 'Year');
      await tester.pumpAndSettle();
      expect(streams, hasLength(2));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('a'), findsOneWidget, reason: 'old rows stay');

      streams.last.add([item('b'), item('a')]);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('b')).dy,
        lessThan(tester.getTopLeft(find.text('a')).dy),
      );
    });
  });
}
