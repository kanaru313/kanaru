import 'dart:async';

import 'package:drift/drift.dart' show QueryExecutor, QueryInterceptor;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_page_queries.dart';
import 'package:kanaru/core/database/playlist_queries.dart';

import '../../library/browse_test_data.dart';
import '../../library/library_test_harness.dart';
import '../playlist_test_data.dart';
import 'playlist_modal_test_support.dart';

void main() {
  late LibraryHarness h;
  setUp(() => h = LibraryHarness());

  testWidgets('Play next waits for the opener, then queues the new order', (
    tester,
  ) async {
    await insertTracks(tester, h, const [
      TestTrack('a'),
      TestTrack('b'),
      TestTrack('c'),
    ]);
    final id = await seedPlaylist(tester, h, 'Mix', ['a', 'b', 'c']);
    final pending = Completer<void>();
    await pumpModalHost(tester, h, id: id, beforeRead: () => pending.future);
    await openPlaylistModalOf(tester);

    await tester.tap(find.byKey(const ValueKey('playlist-modal-play-next')));
    await settleModal(tester);
    expect(queueTitles(h), isEmpty, reason: 'still waiting for the write');

    // The write the opener had in flight lands, then the gate opens.
    final entries = await tester.runAsync(
      () => h.db.playlistEntriesAt(id, 0, 3),
    );
    await tester.runAsync(
      () => h.db.movePlaylistEntry(id, entries!.last.entry.entryId, 0),
    );
    pending.complete();
    await settleModal(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(queueTitles(h), ['c', 'a', 'b']);
  });

  testWidgets('Export, Duplicate and the clean-ups wait too', (tester) async {
    await insertTracks(tester, h, const [TestTrack('a'), TestTrack('b')]);
    final id = await seedPlaylist(tester, h, 'Mix', ['a', 'b', 'a']);
    final pending = Completer<void>();
    await pumpModalHost(tester, h, id: id, beforeRead: () => pending.future);
    await openPlaylistModalOf(tester);
    await tapModalAction(tester, 'advanced');
    await tapModalAction(tester, 'duplicate');

    var playlists = await tester.runAsync(
      () => h.db.select(h.db.playlists).get(),
    );
    expect(playlists, hasLength(1), reason: 'copy waits for the gate');
    pending.complete();
    await settleModal(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    playlists = await tester.runAsync(() => h.db.select(h.db.playlists).get());
    expect(playlists, hasLength(2));
  });

  testWidgets('a failing gate does not block the action', (tester) async {
    await insertTracks(tester, h, const [TestTrack('a'), TestTrack('b')]);
    final id = await seedPlaylist(tester, h, 'Mix', ['a', 'b']);
    await pumpModalHost(
      tester,
      h,
      id: id,
      beforeRead: () => Future<void>.error(StateError('write failed')),
    );
    await openPlaylistModalOf(tester);
    await tester.tap(find.byKey(const ValueKey('playlist-modal-play-next')));
    await settleModal(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(queueTitles(h), ['a', 'b']);
  });

  group('entry reads wait for the gate', () {
    final reads = <String>[];

    setUp(() {
      reads.clear();
      h = LibraryHarness(interceptor: _ReadLog(reads));
    });

    bool readPaths() =>
        reads.any((q) => q.contains('SELECT path FROM playlist_entries'));
    bool readPlayable() => reads.any(
      (q) => q.contains('e.id AS entry_id') && !q.contains('LEFT JOIN'),
    );

    Future<Completer<void>> openGated(WidgetTester tester) async {
      await insertTracks(tester, h, const [TestTrack('a'), TestTrack('b')]);
      final id = await seedPlaylist(tester, h, 'Mix', ['a', 'b']);
      final gate = Completer<void>();
      await pumpModalHost(tester, h, id: id, beforeRead: () => gate.future);
      await openPlaylistModalOf(tester);
      reads.clear();
      return gate;
    }

    testWidgets('Add to playlist reads the paths only after the gate', (
      tester,
    ) async {
      final gate = await openGated(tester);
      await tapModalAction(tester, 'add-to-playlist');
      expect(readPaths(), isFalse);
      gate.complete();
      await settleModal(tester);
      expect(readPaths(), isTrue);
    });

    testWidgets('Add all to Favorites reads the songs only after the gate', (
      tester,
    ) async {
      final gate = await openGated(tester);
      await tapModalAction(tester, 'advanced');
      await tapModalAction(tester, 'add-all-to-favorites');
      expect(readPlayable(), isFalse);
      gate.complete();
      await settleModal(tester);
      expect(readPlayable(), isTrue);
    });
  });
}

/// Records every SELECT the database runs.
class _ReadLog extends QueryInterceptor {
  _ReadLog(this.log);
  final List<String> log;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    log.add(statement);
    return executor.runSelect(statement, args);
  }
}
