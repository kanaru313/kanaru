import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/playlists/optimistic_order.dart';

void main() {
  late OptimisticOrder order;
  const rows = [1, 2, 3];

  List<int> shown([List<int> from = rows]) => order.apply(from, (id) => id);

  setUp(() => order = OptimisticOrder());

  test('shows the stream order when nothing was dropped', () {
    expect(shown(), rows);
  });

  test('a dropped order wins over the stream while the write runs', () {
    order.begin([2, 3, 1]);

    expect(shown(), [2, 3, 1]);
  });

  test('data after the write finished replaces the pending order', () {
    order.begin([2, 3, 1]);
    order.end(ok: true);
    order.onData([2, 3, 1]);

    expect(shown([2, 3, 1]), [2, 3, 1]);
    expect(shown([3, 2, 1]), [3, 2, 1], reason: 'pending is gone');
  });

  test('the dropped order stays after the write until new data arrives', () {
    order.begin([2, 3, 1]);
    order.end(ok: true);

    // No onData: the stream has not caught up yet.
    expect(shown(), [2, 3, 1]);
  });

  test('a stale value mid-write keeps the pending order', () {
    order.begin([2, 3, 1]);
    order.onData(rows);

    expect(shown(), [2, 3, 1]);

    order.end(ok: true);
    order.onData([2, 3, 1]);
    expect(shown([2, 3, 1]), [2, 3, 1]);
    expect(shown(), rows, reason: 'cleared by the next value');
  });

  test('a value that already agrees ends the optimistic order early', () {
    order.begin([2, 3, 1]);
    order.onData([2, 3, 1]);

    expect(shown([3, 1, 2]), [3, 1, 2]);
  });

  test('a failed write rolls back to the stream order', () {
    order.begin([2, 3, 1]);
    order.end(ok: false);

    expect(shown(), rows);
  });

  test('two drops before any write ends show the second order', () {
    order.begin([2, 3, 1]);
    order.begin([3, 2, 1]);
    expect(shown(), [3, 2, 1]);

    order.end(ok: true);
    order.onData([2, 3, 1]);
    expect(shown(), [3, 2, 1], reason: 'one write is still in flight');

    order.end(ok: true);
    order.onData([3, 2, 1]);
    expect(shown([3, 2, 1]), [3, 2, 1]);
    expect(shown(), rows, reason: 'both ended and data arrived');
  });

  test('an id added meanwhile goes after the known ones', () {
    order.begin([3, 1, 2]);

    expect(shown([1, 2, 3, 4]), [3, 1, 2, 4]);
  });

  test('an id removed meanwhile is dropped', () {
    order.begin([3, 1, 2]);

    expect(shown([1, 3]), [3, 1]);
  });

  test('is busy from begin until the write ends', () {
    expect(order.busy, isFalse);
    order.begin([2, 3, 1]);
    expect(order.busy, isTrue);
    order.end(ok: true);
    expect(order.busy, isFalse);
  });
}
