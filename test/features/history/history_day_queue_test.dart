import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/history_rows.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/features/history/history_day_queue.dart';

HistoryPlayRow _play(int id, String path, {bool inLibrary = true}) =>
    HistoryPlayRow(
      id: id,
      path: path,
      playedAt: id,
      track: inLibrary
          ? TrackListItem(id: id, path: path, title: 'T${path.split('/').last}')
          : null,
    );

void main() {
  test('a day lists each song once at its first place, gone ones left out', () {
    final rows = [
      _play(5, '/m/gone', inLibrary: false),
      _play(4, '/m/c'),
      _play(3, '/m/a'),
      _play(2, '/m/c'),
      _play(1, '/m/a'),
    ];

    expect(historyDayTracks(rows, null).map((t) => t.uri), ['/m/c', '/m/a']);
    expect(historyDayTracks(const [], null), isEmpty);
  });

  test('plays each song of the day once, starting at the tapped one', () {
    final rows = [
      _play(4, '/m/c'),
      _play(3, '/m/a'),
      _play(2, '/m/b'),
      _play(1, '/m/a'),
    ];

    final queue = historyDayQueue(rows, rows[2], null)!;

    expect(queue.tracks.map((t) => t.uri), ['/m/c', '/m/a', '/m/b']);
    expect(queue.start, 2);
  });

  test('a repeat of a song starts the first appearance of it', () {
    final rows = [_play(4, '/m/c'), _play(3, '/m/a'), _play(1, '/m/a')];

    final queue = historyDayQueue(rows, rows.last, null)!;

    expect(queue.tracks.map((t) => t.uri), ['/m/c', '/m/a']);
    expect(queue.start, 1);
  });

  test('songs gone from the library are left out; the index follows', () {
    final rows = [
      _play(4, '/m/gone', inLibrary: false),
      _play(3, '/m/a'),
      _play(2, '/m/b'),
    ];

    final queue = historyDayQueue(rows, rows[2], null)!;

    expect(queue.tracks.map((t) => t.uri), ['/m/a', '/m/b']);
    expect(queue.start, 1);
  });

  test('a play that cannot play queues nothing', () {
    final rows = [_play(2, '/m/gone', inLibrary: false), _play(1, '/m/a')];

    expect(historyDayQueue(rows, rows.first, null), isNull);
  });

  test('a day read again without the tapped song still plays that song', () {
    final tapped = _play(9, '/m/x');

    final queue = historyDayQueue([_play(1, '/m/a')], tapped, null)!;

    expect(queue.tracks.map((t) => t.uri), ['/m/x']);
    expect(queue.start, 0);
  });

  test('the player gets the library row path, with its tags', () {
    final row = HistoryPlayRow(
      id: 1,
      path: '/m/old-spelling.flac',
      playedAt: 1,
      track: const TrackListItem(
        id: 7,
        path: '/m/canonical.flac',
        title: 'Song',
        artist: 'Ann',
        durationMs: 2000,
      ),
    );

    final track = historyTrackOf(row, null);

    expect(track.uri, '/m/canonical.flac');
    expect(track.title, 'Song');
    expect(track.artist, 'Ann');
    expect(track.duration, const Duration(seconds: 2));
  });
}
