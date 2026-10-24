import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/player/queue/queue_sections.dart';

/// A row of the upcoming list in the brute-force model: a play position, or
/// `null` for the "Up next" header.
typedef _Row = int?;

/// Builds the upcoming rows the slow way, from the definition: Play next
/// tracks, the header (when there are any), the other upcoming tracks.
List<_Row> _rows(int index, int playNext, int length) => [
  for (var p = index + 1; p <= index + playNext; p++) p,
  if (playNext > 0) null,
  for (var p = index + 1 + playNext; p < length; p++) p,
];

void main() {
  group('QueueSections mapping', () {
    test('an empty queue has nothing in any section', () {
      final s = QueueSections(index: 0, playNext: 0, length: 0);
      expect(s.played, 0);
      expect(s.upcomingRows, 0);
      expect(s.hasUpNextHeader, isFalse);
    });

    test('counts rows with and without the header', () {
      final plain = QueueSections(index: 2, playNext: 0, length: 6);
      expect(plain.played, 2);
      expect(plain.upcomingRows, 3);
      expect(plain.hasUpNextHeader, isFalse);

      final run = QueueSections(index: 2, playNext: 2, length: 6);
      expect(run.upcomingRows, 4);
      expect(run.hasUpNextHeader, isTrue);
    });

    test('a run longer than the upcoming tracks is clamped', () {
      final s = QueueSections(index: 1, playNext: 9, length: 4);
      expect(s.playNext, 2);
      expect(s.upcomingRows, 3);
    });

    test('the header stays when the run takes every upcoming track', () {
      final s = QueueSections(index: 0, playNext: 2, length: 3);
      expect(s.upcomingRows, 3);
      expect(s.positionOfRow(2), isNull);
    });

    test('rows map to positions and back, exhaustively', () {
      for (var length = 0; length <= 8; length++) {
        for (var index = 0; index < (length == 0 ? 1 : length); index++) {
          for (var run = 0; run <= 3; run++) {
            final s = QueueSections(
              index: index,
              playNext: run,
              length: length,
            );
            if (length == 0) continue;
            if (run > length - index - 1) continue;
            final model = _rows(index, run, length);
            expect(s.upcomingRows, model.length);
            for (var row = 0; row < model.length; row++) {
              expect(s.positionOfRow(row), model[row], reason: '$index $run');
              final position = model[row];
              if (position != null) {
                expect(s.rowOfPosition(position), row);
                expect(s.isPlayNextRow(row), position <= index + run);
              }
            }
          }
        }
      }
    });
  });

  group('QueueSections drop', () {
    test('the header cannot be dragged', () {
      final s = QueueSections(index: 0, playNext: 2, length: 6);
      for (var to = 0; to < s.upcomingRows; to++) {
        expect(s.drop(2, to), isNull);
      }
    });

    test('matches a brute-force list simulation for every drag', () {
      var checked = 0;
      for (var length = 2; length <= 8; length++) {
        for (var index = 0; index <= 3 && index < length; index++) {
          for (var run = 0; run <= 3 && run <= length - index - 1; run++) {
            final s = QueueSections(
              index: index,
              playNext: run,
              length: length,
            );
            final rows = _rows(index, run, length);
            for (var from = 0; from < rows.length; from++) {
              for (var to = 0; to < rows.length; to++) {
                final drop = s.drop(from, to);
                final reason =
                    'index $index run $run length $length '
                    'drag $from -> $to';
                if (rows[from] == null) {
                  expect(drop, isNull, reason: reason);
                  continue;
                }
                // Reorder the rows like the list does, header included.
                final moved = [...rows];
                final dragged = moved.removeAt(from);
                moved.insert(to, dragged);
                final header = moved.indexOf(null);
                final expectedOrder = [...moved.nonNulls];
                final expectedPlayNext = header >= 0 && to < header;

                expect(drop, isNotNull, reason: reason);
                // Apply the drop to the whole queue like `moveTrack` does:
                // take the track at `from`, put it at `to`.
                final queue = [for (var p = 0; p < length; p++) p];
                final taken = queue.removeAt(drop!.from);
                queue.insert(drop.to, taken);
                expect(queue.sublist(index + 1), expectedOrder, reason: reason);
                expect(drop.playNext, expectedPlayNext, reason: reason);
                checked++;
              }
            }
          }
        }
      }
      expect(checked, greaterThan(500));
    });

    test('a drop just across the header changes section in place', () {
      // Rows: [a, b, header, c, d]; dragging c up to row 2 (just above the
      // header) joins Play next at the same play position.
      final s = QueueSections(index: 0, playNext: 2, length: 5);
      final up = s.drop(3, 2)!;
      expect(up.from, 3);
      expect(up.to, 3);
      expect(up.playNext, isTrue);
      // Dragging b down to row 2 leaves Play next at the same position.
      final down = s.drop(1, 2)!;
      expect(down.from, 2);
      expect(down.to, 2);
      expect(down.playNext, isFalse);
    });

    test('without a run nothing is ever a Play next drop', () {
      final s = QueueSections(index: 1, playNext: 0, length: 5);
      final d = s.drop(0, 2)!;
      expect(d, (from: 2, to: 4, playNext: false));
    });
  });
}
