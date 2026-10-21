import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart' show TrackListItem;
import 'package:kanaru/features/library/songs/song_row_cache.dart';

TrackListItem _item(int id, [String? title]) =>
    TrackListItem(id: id, path: '/$id', title: title ?? 't$id');

void main() {
  late List<List<int>> requests;
  late List<Completer<List<TrackListItem>>> pending;
  var changed = 0;

  var clock = DateTime(2026);

  SongRowCache make({int maxRows = 1200, int pageSize = 4, int maxReads = 2}) {
    clock = DateTime(2026);
    requests = [];
    pending = [];
    changed = 0;
    return SongRowCache(
      maxRows: maxRows,
      pageSize: pageSize,
      maxReads: maxReads,
      now: () => clock,
      onChanged: () => changed++,
      load: (ids) {
        requests.add(ids);
        final c = Completer<List<TrackListItem>>();
        pending.add(c);
        return c.future;
      },
    );
  }

  Future<void> answer(int i, [String? title]) async {
    pending[i].complete([for (final id in requests[i]) _item(id, title)]);
    await pumpEventQueue();
  }

  test('asks once per page and fills the page', () async {
    final cache = make()..setIds([for (var i = 0; i < 10; i++) i * 10]);
    expect(cache.rowAt(5), isNull);
    expect(cache.rowAt(6), isNull);
    expect(requests, [
      [40, 50, 60, 70],
    ]);
    await answer(0);
    expect(changed, 1);
    expect(cache.rowAt(5)?.id, 50);
    expect(requests, hasLength(1), reason: 'the page is fresh');
    // The last page is short.
    cache.rowAt(9);
    expect(requests.last, [80, 90]);
  });

  test('a load that started under an older generation is dropped', () async {
    final cache = make()..setIds([1, 2, 3, 4]);
    cache.rowAt(0);
    cache.setIds([4, 3, 2, 1]);
    expect(cache.generation, 2);
    await answer(0, 'old');
    expect(changed, 0);
    expect(cache.length, 0);

    // The page is asked for again under the new generation.
    cache.rowAt(0);
    expect(requests, hasLength(2));
    expect(requests.last, [4, 3, 2, 1]);
    await answer(1, 'new');
    expect(cache.rowAt(0)?.title, 'new');
  });

  test('rows stay shown across a refresh and are read again', () async {
    final cache = make()..setIds([1, 2, 3, 4]);
    cache.rowAt(0);
    await answer(0, 'before');
    cache.setIds([1, 2, 3, 4, 5]);
    expect(cache.rowAt(0)?.title, 'before', reason: 'no gap on screen');
    expect(requests, hasLength(2), reason: 'read again in the background');
    await answer(1, 'after');
    expect(cache.rowAt(0)?.title, 'after');
  });

  test('the same list again changes nothing', () async {
    final ids = [1, 2, 3, 4];
    final cache = make()..setIds(ids);
    cache.rowAt(0);
    await answer(0);
    cache.setIds(ids);
    cache.rowAt(0);
    expect(requests, hasLength(1));
    expect(cache.generation, 1);
  });

  test('keeps at most maxRows, dropping the oldest read', () async {
    final cache = make(maxRows: 6)..setIds([for (var i = 0; i < 12; i++) i]);
    for (final index in [0, 4, 8]) {
      cache.rowAt(index);
      await answer(requests.length - 1);
    }
    expect(cache.length, 6);
    expect(cache.rowAt(11)?.id, 11);
    // Page 0 was the oldest: gone and read again when asked for.
    final before = requests.length;
    expect(cache.rowAt(0), isNull);
    expect(requests, hasLength(before + 1));
  });

  test('a failed read is asked for again on the next draw', () async {
    final cache = make()..setIds([1, 2, 3, 4]);
    cache.rowAt(0);
    pending[0].completeError(StateError('db gone'));
    await pumpEventQueue();
    cache.rowAt(0);
    expect(requests, hasLength(2));
  });

  test('after dispose nothing is read or reported', () async {
    final cache = make()..setIds([1, 2, 3, 4]);
    cache.rowAt(0);
    cache.dispose();
    await answer(0);
    expect(changed, 0);
    cache.rowAt(0);
    expect(requests, hasLength(1));
  });

  test('a track that is gone is not asked for again and has no row', () async {
    final cache = make()..setIds([1, 2, 3, 4]);
    cache.rowAt(0);
    pending[0].complete([_item(1), _item(3), _item(4)]);
    await pumpEventQueue();
    for (var i = 0; i < 5; i++) {
      expect(cache.rowAt(1), isNull);
      expect(cache.rowAt(0)?.id, 1);
    }
    expect(requests, hasLength(1));
    // The next list asks again.
    cache.setIds([1, 2, 3, 4, 5]);
    expect(cache.rowAt(1), isNull);
    expect(requests, hasLength(2));
  });

  test('a stale row of a track that is gone is dropped', () async {
    final cache = make()..setIds([1, 2, 3, 4]);
    cache.rowAt(0);
    await answer(0);
    cache.setIds([1, 2, 3, 4, 5]);
    cache.rowAt(0);
    pending[1].complete([_item(1), _item(3), _item(4)]);
    await pumpEventQueue();
    expect(cache.rowAt(1), isNull);
  });

  test('an empty answer is not asked for again', () async {
    final cache = make()..setIds([1, 2, 3, 4]);
    cache.rowAt(0);
    pending[0].complete(const []);
    await pumpEventQueue();
    for (var i = 0; i < 5; i++) {
      cache.rowAt(0);
    }
    expect(requests, hasLength(1));
  });

  test('at most maxReads run, the newest request goes first', () async {
    final cache = make()..setIds([for (var i = 0; i < 40; i++) i]);
    for (var page = 0; page < 10; page++) {
      cache.rowAt(page * 4);
    }
    expect(cache.reading, 2);
    expect(requests, hasLength(2));
    await answer(0);
    expect(cache.reading, 2);
    expect(requests[2].first, 36, reason: 'page 9 was asked for last');
    await answer(1);
    expect(requests[3].first, 32);
  });

  test('a waiting page nobody asked for lately is skipped', () async {
    final cache = make()..setIds([for (var i = 0; i < 16; i++) i]);
    for (final page in [0, 1, 2, 3]) {
      cache.rowAt(page * 4);
    }
    clock = clock.add(const Duration(milliseconds: 400));
    cache.rowAt(12); // still on screen: asked for again
    await answer(0);
    expect(requests[2].first, 12);
    await answer(1);
    // Pages 2 and 3 waited without being asked for again: skipped.
    expect(requests, hasLength(3));
    expect(cache.reading, 1);
    // A skipped page that comes back on screen is read.
    cache.rowAt(8);
    expect(requests.last.first, 8);
  });
}
