import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/features/playlists/playlist_row_cache.dart';

PlaylistEntryRow entryRow(int id) =>
    PlaylistEntryRow(entryId: id, path: '/m/$id');

/// Entries for positions [start, end), each with entry id = position.
List<PlaylistPositionedEntry> answerFor(int start, int end) => [
  for (var i = start; i < end; i++) PlaylistPositionedEntry(i, entryRow(i)),
];

class _Read {
  _Read(this.start, this.count);

  final int start;
  final int count;
  final done = Completer<List<PlaylistPositionedEntry>>();
}

void main() {
  late List<_Read> reads;
  late var changed = 0;
  late DateTime clock;
  late PlaylistRowCache cache;

  PlaylistRowCache build({int maxRows = 1200, int pageSize = 10}) =>
      PlaylistRowCache(
        pageSize: pageSize,
        maxRows: maxRows,
        load: (start, count) {
          final read = _Read(start, count);
          reads.add(read);
          return read.done.future;
        },
        onChanged: () => changed++,
        now: () => clock,
      );

  /// Lets microtasks and completed futures run.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  Future<void> answer(_Read read, [int? end]) async {
    read.done.complete(answerFor(read.start, end ?? read.start + read.count));
    await flush();
  }

  setUp(() {
    reads = [];
    changed = 0;
    clock = DateTime(2026);
    cache = build()..reset(35);
  });
  tearDown(() => cache.dispose());

  test('a row is read with its page when first asked for', () async {
    expect(cache.rowAt(13), isNull, reason: 'placeholder until the page');
    expect([for (final r in reads) (r.start, r.count)], [(10, 10)]);

    await answer(reads.single);

    expect(cache.rowAt(13)?.entryId, 13);
    expect(cache.rowAt(19)?.entryId, 19);
    expect(reads, hasLength(1), reason: 'the page is fresh, no new read');
    expect(changed, 1);
  });

  test('the last page asks for the rows that are left', () {
    cache.rowAt(34);

    expect((reads.single.start, reads.single.count), (30, 5));
  });

  test('an index outside the list is null and reads nothing', () {
    expect(cache.rowAt(-1), isNull);
    expect(cache.rowAt(35), isNull);
    expect(reads, isEmpty);
  });

  test('rows go where their position says, not where they came', () async {
    cache.rowAt(0);
    reads.single.done.complete([
      PlaylistPositionedEntry(3, entryRow(103)),
      PlaylistPositionedEntry(1, entryRow(101)),
      // Outside the page, and outside the list: dropped.
      PlaylistPositionedEntry(12, entryRow(112)),
      PlaylistPositionedEntry(-1, entryRow(99)),
      PlaylistPositionedEntry(40, entryRow(140)),
    ]);
    await flush();

    expect(cache.rowAt(1)?.entryId, 101);
    expect(cache.rowAt(3)?.entryId, 103);
    expect(cache.rowAt(0), isNull, reason: 'a gap is a placeholder');
    expect(cache.rowAt(2), isNull);
    expect(cache.rowAt(9), isNull);
    expect(cache.length, 2);
    expect(reads, hasLength(1), reason: 'the page counts as answered');
  });

  test('a gap loses the stale row it had', () async {
    cache.rowAt(0);
    await answer(reads.single);
    cache.reset(35);
    expect(cache.rowAt(2)?.entryId, 2, reason: 'stale row still drawn');
    reads.last.done.complete([PlaylistPositionedEntry(0, entryRow(50))]);
    await flush();

    expect(cache.rowAt(0)?.entryId, 50);
    expect(cache.rowAt(2), isNull);
  });

  test('at most maxReads run at once, the newest request first', () async {
    cache.rowAt(0);
    cache.rowAt(10);
    cache.rowAt(20);
    cache.rowAt(30);

    expect([for (final r in reads) r.start], [0, 10]);

    await answer(reads[0]);
    expect([for (final r in reads) r.start], [0, 10, 30], reason: 'newest');

    await answer(reads[1]);
    expect([for (final r in reads) r.start], [0, 10, 30, 20]);
  });

  test('asking again makes a waiting page the newest', () async {
    cache.rowAt(0);
    cache.rowAt(10);
    cache.rowAt(20);
    cache.rowAt(30);
    cache.rowAt(20);

    await answer(reads[0]);

    expect(reads.last.start, 20);
  });

  test('a page nobody asked for lately is skipped and the list told', () async {
    cache.rowAt(0);
    cache.rowAt(10);
    cache.rowAt(20);
    clock = clock.add(const Duration(milliseconds: 301));
    final before = changed;

    await answer(reads[0]);

    expect(reads, hasLength(2), reason: 'page 2 was not read');
    expect(changed, before + 2, reason: 'the answer and the skipped page');
    // On screen again: asked for and read now.
    cache.rowAt(20);
    expect(reads.last.start, 20);
  });

  test('reset keeps rows as stale and reads them again', () async {
    cache.rowAt(0);
    await answer(reads.single);

    cache.reset(35);

    expect(cache.rowAt(5)?.entryId, 5, reason: 'stale row is returned');
    expect(reads, hasLength(2));
    reads.last.done.complete([PlaylistPositionedEntry(5, entryRow(500))]);
    await flush();
    expect(cache.rowAt(5)?.entryId, 500);
  });

  test('reset drops rows past the new count', () async {
    cache.rowAt(30);
    await answer(reads.single);
    expect(cache.rowAt(34), isNotNull);

    cache.reset(32);

    expect(cache.count, 32);
    expect(cache.rowAt(34), isNull);
    expect(cache.length, 2);
  });

  test(
    'an answer of an older generation is dropped and the list told',
    () async {
      cache.rowAt(0);
      final old = reads.single;
      cache.reset(35);
      final before = changed;

      await answer(old);

      expect(changed, before + 1);
      expect(cache.length, 0, reason: 'the old answer is not stored');
      // The page is asked for again under the new generation.
      cache.rowAt(0);
      expect(reads, hasLength(2));
    },
  );

  group('edits', () {
    setUp(() async {
      cache.rowAt(0);
      cache.rowAt(10);
      await answer(reads[0]);
      await answer(reads[1]);
    });

    test('move shifts the rows between like a list insert', () {
      cache.move(2, 5);

      expect(
        [for (var i = 0; i < 8; i++) cache.rowAt(i)?.entryId],
        [
          0, 1, 3, 4, 5, 2, 6, 7, //
        ],
      );

      cache.move(5, 0);
      expect(
        [for (var i = 0; i < 8; i++) cache.rowAt(i)?.entryId],
        [
          2, 0, 1, 3, 4, 5, 6, 7, //
        ],
      );
    });

    test('move across pages leaves what is not cached not cached', () {
      cache.move(3, 25);

      expect(cache.rowAt(25)?.entryId, 3, reason: 'the moved row came along');
      expect(cache.rowAt(24), isNull, reason: 'page 2 was never read');
      expect(cache.rowAt(3)?.entryId, 4);
      expect(cache.length, 20, reason: 'no row lost, none invented');
    });

    test('removeAt closes the gap and shortens the list', () {
      cache.removeAt(1);

      expect(cache.count, 34);
      expect(
        [for (var i = 0; i < 4; i++) cache.rowAt(i)?.entryId],
        [
          0, 2, 3, 4, //
        ],
      );
      expect(cache.length, 19);
    });

    test('an edit drops the answers of reads on their way', () async {
      cache.rowAt(30);
      final inFlight = reads.last;

      cache.removeAt(0);
      await answer(inFlight);

      expect(cache.length, 19, reason: 'page 3 was not stored');
    });
  });

  group('hold', () {
    test('starts no read and drops answers until released', () async {
      cache.rowAt(0);
      final running = reads.single;

      cache.hold();
      cache.rowAt(10);
      expect(reads, hasLength(1), reason: 'no read while held');
      await answer(running);
      expect(cache.length, 0, reason: 'the answer was dropped');

      cache.release();
      cache.rowAt(10);
      expect(reads, hasLength(2));
    });

    test('edits shift rows without reading while held', () async {
      cache.rowAt(0);
      await answer(reads.single);

      cache.hold();
      cache.move(0, 3);
      cache.removeAt(0);

      expect(reads, hasLength(1));
      expect([for (var i = 0; i < 3; i++) cache.rowAt(i)?.entryId], [2, 3, 0]);
    });
  });

  test('rows over maxRows go oldest first and are read again', () async {
    cache.dispose();
    cache = build(maxRows: 15)..reset(35);
    cache.rowAt(0);
    await answer(reads[0]);
    cache.rowAt(10);
    await answer(reads[1]);

    expect(cache.length, 15);
    expect(cache.rowAt(10), isNotNull);
    expect(cache.rowAt(9), isNotNull, reason: 'the five oldest went');
    expect(cache.rowAt(0), isNull);
    expect(reads.last.start, 0, reason: 'the evicted page is asked again');
  });

  test('a failed read is asked for again at the next draw', () async {
    cache.rowAt(0);
    reads.single.done.completeError(StateError('db closed'));
    await flush();

    expect(cache.reading, 0);
    cache.rowAt(0);
    expect(reads, hasLength(2));
  });

  test('a disposed cache ignores answers and asks for nothing', () async {
    cache.rowAt(0);
    final running = reads.single;
    cache.dispose();
    final before = changed;

    await answer(running);
    cache.rowAt(10);

    expect(changed, before);
    expect(reads, hasLength(1));
    expect(cache.length, 0);
  });
}
