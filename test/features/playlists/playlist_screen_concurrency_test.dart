import 'dart:async';

import 'package:drift/drift.dart' show QueryExecutor, QueryInterceptor, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/playlist_favorites.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/features/playlists/playlist_page_data.dart';
import 'package:kanaru/shared/icons/app_icons.dart';

import '../../core/stats/gated_query_interceptor.dart';

import '../library/library_test_harness.dart';
import 'playlist_test_data.dart';

/// Holds the first statement that contains [pattern] until
/// [releaseAndFail], then makes it throw, like a write that dies after
/// waiting for its turn.
class _FailAfterHold extends QueryInterceptor {
  _FailAfterHold(this.pattern);

  final String pattern;
  final _gate = Completer<void>();
  var held = false;
  var deletes = 0;

  void releaseAndFail() => _gate.complete();

  @override
  Future<int> runDelete(QueryExecutor e, String s, List<Object?> a) {
    deletes++;
    return super.runDelete(e, s, a);
  }

  @override
  Future<int> runUpdate(QueryExecutor e, String s, List<Object?> a) async {
    if (!held && s.contains(pattern)) {
      held = true;
      await _gate.future;
      throw StateError('injected failure');
    }
    return super.runUpdate(e, s, a);
  }
}

/// Edits that overlap each other, or other writers (a like in the player, a
/// scan), on a playlist page over a real database. The page must never show
/// a state the database does not head for, even for a frame.
void main() {
  late LibraryHarness h;

  setUp(() => h = LibraryHarness(refreshInterval: Duration.zero));

  /// Pumps frames until the playlist holds [count] entries, noting the rows
  /// and whether the count text shows [staleCount] after each frame.
  Future<List<({List<String> titles, bool stale})>> framesUntil(
    WidgetTester tester,
    int id,
    int count,
    String staleCount,
  ) async {
    final frames = <({List<String> titles, bool stale})>[];
    void note() => frames.add((
      titles: shownTitles(tester),
      stale: find.text(staleCount).evaluate().isNotEmpty,
    ));
    note();
    await pumpUntil(
      tester,
      () async => (await h.db.playlistPage(id))!.entries.length == count,
      onFrame: note,
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      note();
    }
    await settleDb(tester);
    note();
    return frames;
  }

  testWidgets('a removal never brings the row back while the page reloads', (
    tester,
  ) async {
    final id = await openMix(tester, h);

    await removeRowViaModal(tester, 1);
    await tester.pump();
    final frames = await framesUntil(tester, id, 3, '4 songs');

    const expected = ['Alpha', 'Charlie', 'Delta'];
    for (final frame in frames) {
      expect(frame.titles, expected, reason: 'frames: $frames');
      expect(frame.stale, isFalse);
    }
    expect(playlistSongCount('3 songs'), findsOneWidget);
  });

  const moveStatement = 'UPDATE playlist_entries SET position = position';

  /// Lets work in the database isolate run for a moment.
  Future<void> letDbRun(WidgetTester tester) => tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );

  testWidgets('a removal during a move ends in the database order', (
    tester,
  ) async {
    final gate = GatedQueryInterceptor();
    h = LibraryHarness(refreshInterval: Duration.zero, interceptor: gate);
    final id = await openMix(tester, h);
    final paths = await trackPaths(tester, h);
    final release = gate.holdNext(moveStatement);

    await dragFirstRowDown(tester);
    await tester.pumpAndSettle();
    await letDbRun(tester);
    // The move reached the database and is held there.
    expect(gate.count(moveStatement), 1);
    expect(shownTitles(tester), ['Bravo', 'Charlie', 'Alpha', 'Delta']);

    await removeRowViaModal(tester, 1); // Charlie
    await tester.pump();
    await letDbRun(tester);
    expect(shownTitles(tester), ['Bravo', 'Alpha', 'Delta']);
    // The removal waits behind the held move: reading the database now would
    // wait too, so the statements seen so far are the evidence.
    expect(gate.count('DELETE FROM'), 0, reason: 'removal not started');

    release();
    await settleDb(tester);

    expect(shownTitles(tester), ['Bravo', 'Alpha', 'Delta']);
    expect(await storedPaths(tester, h, id), [
      for (final t in ['Bravo', 'Alpha', 'Delta']) paths[t],
    ]);
    expect(playlistSongCount('3 songs'), findsOneWidget);
  });

  testWidgets(
    'a failed move with a removal queued ends in the database state',
    (tester) async {
      final failing = _FailAfterHold(moveStatement);
      h = LibraryHarness(refreshInterval: Duration.zero, interceptor: failing);
      final id = await openMix(tester, h);
      final paths = await trackPaths(tester, h);

      await dragFirstRowDown(tester);
      await tester.pumpAndSettle();
      await letDbRun(tester);
      expect(failing.held, isTrue, reason: 'the move is held in the database');

      await removeRowViaModal(tester, 1); // Charlie
      await tester.pump();
      expect(shownTitles(tester), ['Bravo', 'Alpha', 'Delta']);

      failing.releaseAndFail();
      await settleDb(tester);

      // The move rolled back and the removal went through.
      expect(failing.deletes, 1);
      const expected = ['Alpha', 'Bravo', 'Delta'];
      expect(shownTitles(tester), expected);
      expect(await storedPaths(tester, h, id), [
        for (final t in expected) paths[t],
      ]);
      expect(playlistSongCount('3 songs'), findsOneWidget);
      expect(
        find.text("Couldn't save the playlist. See the log for details."),
        findsOneWidget,
      );
    },
  );

  testWidgets('a failed removal goes back to the database state', (
    tester,
  ) async {
    final id = await openMix(tester, h);
    await breakWrites(tester, h, 'playlist_entries', 'DELETE');

    await removeRowViaModal(tester, 1);
    await tester.pump();
    await settleDb(tester);

    expect(shownTitles(tester), mixTitles);
    expect(playlistSongCount('4 songs'), findsOneWidget);
    expect(await storedPaths(tester, h, id), hasLength(4));
  });

  Future<void> renameDelta(WidgetTester tester) => tester.runAsync(
    () => (h.db.update(h.db.tracks)..where((t) => t.title.equals('Delta')))
        .write(const TracksCompanion(title: Value('Delta 2'))),
  );

  testWidgets('a scan while a move is saved keeps the order and shows tags', (
    tester,
  ) async {
    final id = await openMix(tester, h);
    final paths = await trackPaths(tester, h);

    await dragFirstRowDown(tester);
    await renameDelta(tester);
    await pumpUntil(
      tester,
      () async =>
          [for (final e in (await h.db.playlistPage(id))!.entries) e.path]
              .join() ==
          [
            for (final t in ['Bravo', 'Charlie', 'Alpha', 'Delta']) paths[t],
          ].join(),
    );
    await settleDb(tester);

    expect(shownTitles(tester), ['Bravo', 'Charlie', 'Alpha', 'Delta 2']);
  });

  testWidgets('a scan during a drag changes nothing until the drop', (
    tester,
  ) async {
    final id = await openMix(tester, h);
    final paths = await trackPaths(tester, h);
    final heads = <int>[];
    h.container.listen(playlistPageHeadProvider(id), (_, next) {
      if (next.value case final load?) heads.add(load.seq);
    }, fireImmediately: true);

    final handle = find.byIcon(AppIcons.dragHandle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 18; i++) {
      await gesture.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await renameDelta(tester);
    await letDbRun(tester);
    await tester.pump();
    expect(
      shownTitles(tester),
      contains('Delta'),
      reason: 'not under the hand',
    );
    expect(shownTitles(tester), isNot(contains('Delta 2')));

    await gesture.up();
    await settleDb(tester);

    expect(shownTitles(tester), ['Bravo', 'Charlie', 'Alpha', 'Delta 2']);
    expect(await storedPaths(tester, h, id), [
      for (final t in ['Bravo', 'Charlie', 'Alpha', 'Delta']) paths[t],
    ]);
  });

  group('favorites', () {
    Future<void> like(WidgetTester tester, String title) async {
      final paths = await trackPaths(tester, h);
      await tester.runAsync(
        () => h.db.setFavorite(paths[title]!, favorite: true, now: 1),
      );
    }

    Future<void> unlike(WidgetTester tester, String title) async {
      final paths = await trackPaths(tester, h);
      await tester.runAsync(
        () => h.db.setFavorite(paths[title]!, favorite: false, now: 1),
      );
    }

    testWidgets('a heart toggled elsewhere shows up on the open page', (
      tester,
    ) async {
      await openApp(tester, h, ['a', 'b', 'c'], location: '/favorites');
      await like(tester, 'a');
      await like(tester, 'b');
      await settleDb(tester);
      expect(shownTitles(tester), ['a', 'b']);

      await like(tester, 'c');
      await settleDb(tester);
      expect(shownTitles(tester), ['a', 'b', 'c']);
      expect(playlistSongCount('3 songs'), findsOneWidget);

      await unlike(tester, 'a');
      await settleDb(tester);
      expect(shownTitles(tester), ['b', 'c']);
      expect(playlistSongCount('2 songs'), findsOneWidget);
    });

    testWidgets('a heart toggled elsewhere during a removal is not lost', (
      tester,
    ) async {
      await openApp(tester, h, ['a', 'b', 'c'], location: '/favorites');
      await like(tester, 'a');
      await like(tester, 'b');
      await settleDb(tester);

      await tester.tap(find.byTooltip('Remove from favorites').first);
      await like(tester, 'c');
      await settleDb(tester);

      final paths = await trackPaths(tester, h);
      expect(shownTitles(tester), ['b', 'c']);
      expect(playlistSongCount('2 songs'), findsOneWidget);
      expect(
        await tester.runAsync(() => h.db.isFavorite(paths['a']!)),
        isFalse,
      );
      expect(await tester.runAsync(() => h.db.isFavorite(paths['c']!)), isTrue);
    });
  });
}
