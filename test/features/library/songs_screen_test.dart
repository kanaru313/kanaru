import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/core/indexer/tag_reader.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/fake_tag_reader.dart';
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

  Finder rescan() => find.widgetWithText(OutlinedButton, 'Rescan');

  Future<void> scan(WidgetTester tester) async {
    await tester.tap(rescan());
    await settleIo(tester);
  }

  testWidgets('lists scanned songs in title order and plays from the tap', (
    tester,
  ) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    h.touch(music, 'b.mp3');
    h.touch(music, 'a.mp3');
    await openSongs(tester, h, folder: music);
    await scan(tester);

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

  testWidgets('shows progress and disables Rescan while scanning', (
    tester,
  ) async {
    final gated = _GatedTagReader();
    final h = LibraryHarness(reader: gated);
    final music = h.folder('music');
    h.touch(music, 'a.mp3');
    await openSongs(tester, h, folder: music);
    await tester.tap(rescan());
    for (var i = 0; i < 4; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
    }
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Reading tags 0 / 1'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(rescan()).onPressed, isNull);

    gated.release.complete();
    await settleIo(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.widget<OutlinedButton>(rescan()).onPressed, isNotNull);
  });

  testWidgets('reports a failed scan', (tester) async {
    final h = LibraryHarness();
    final music = h.folder('music');
    h.touch(music, 'a.mp3');
    h.reader.throwOnRead = StateError('boom');
    await openSongs(tester, h, folder: music);
    await scan(tester);

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
    await scan(tester);

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
    await settleIo(tester);

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
    await settleIo(tester);

    expect(find.text('$missing was not found'), findsOneWidget);
    expect(await tester.runAsync(h.db.roots), isEmpty);
  });

  testWidgets('folders without songs show the empty message', (tester) async {
    final h = LibraryHarness();
    await openSongs(tester, h, folder: h.folder('music'));

    expect(find.text('No songs found'), findsOneWidget);
    expect(rescan(), findsOneWidget);
  });
}
