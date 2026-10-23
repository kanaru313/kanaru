// Times how long saving the playback session of a 50k-track queue blocks the
// calling (UI) isolate, and how big the file gets. Off by default; run with
//   KANARU_BENCH=1 flutter test test/core/player/session/playback_session_save_benchmark_test.dart
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/session/playback_session.dart';
import 'package:kanaru/core/player/session/playback_session_codec.dart';
import 'package:kanaru/core/player/session/playback_session_file.dart';
import 'package:kanaru/core/player/track.dart';

const _total = 50000;
const _runs = 5;

final _enabled = Platform.environment['KANARU_BENCH'] == '1';

/// Long non-ASCII paths and thumbnails inside the cover folder, like a real
/// library queued whole.
List<Track> _tracks(String covers, {String suffix = ''}) => [
  for (var i = 0; i < _total; i++)
    Track(
      uri:
          '/home/user/Music/Nghệ sĩ ${i % 2000}/Album Đĩa ${i % 9}/'
          '${i % 99} Bài hát số $i$suffix.flac',
      title: 'Bài hát số $i$suffix',
      artist: 'Nghệ sĩ ${i % 2000}',
      artUri:
          '$covers/512/${(i * 7919).toRadixString(16).padLeft(16, '0')}.jpg',
      duration: Duration(seconds: 180 + i % 120),
    ),
];

/// How long the event loop of this isolate stood still while [action] ran:
/// the longest gap between 1 ms timer ticks and the sum of the time beyond
/// 1 ms in every gap longer than 2 ms.
Future<({Duration longest, Duration total, Duration wall})> _blocked(
  Future<void> Function() action,
) async {
  final watch = Stopwatch()..start();
  var last = watch.elapsed;
  var longest = Duration.zero;
  var total = Duration.zero;
  void tick() {
    final now = watch.elapsed;
    final gap = now - last;
    last = now;
    if (gap > longest) longest = gap;
    if (gap > const Duration(milliseconds: 2)) {
      total += gap - const Duration(milliseconds: 1);
    }
  }

  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) => tick());
  // Let the timer start before the work begins.
  await Future<void>.delayed(const Duration(milliseconds: 5));
  last = watch.elapsed;
  final start = watch.elapsed;
  await action();
  tick();
  final wall = watch.elapsed - start;
  timer.cancel();
  return (longest: longest, total: total, wall: wall);
}

/// How every save wrote the file before encoding moved off the UI isolate:
/// the whole session encoded and written from the calling isolate.
Future<bool> _legacySave(
  String path,
  PlaybackSession session,
  String coverDirectory,
) async {
  await File(path).parent.create(recursive: true);
  final temporary = File('$path.$pid.tmp');
  await temporary.writeAsString(
    jsonEncode(encodePlaybackSession(session, coverDirectory: coverDirectory)),
    flush: true,
  );
  await temporary.rename(path);
  return true;
}

/// A sink for [_legacySave] with the same calls as `PlaybackSessionFile`.
class _Saver {
  _Saver(this.save, this.flush);

  final Future<bool> Function(PlaybackSession) save;
  final Future<void> Function() flush;
}

String _ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(1);

String _stats(List<Duration> values) {
  final sorted = [...values]..sort();
  return 'best ${_ms(sorted.first)} ms, median ${_ms(sorted[sorted.length ~/ 2])} ms';
}

void main() {
  for (final legacy in [true, false]) {
    test(
      legacy
          ? 'saving a 50k-track session, encoded on the calling isolate'
          : 'saving a 50k-track session, encoded off the calling isolate',
      skip: _enabled ? false : 'set KANARU_BENCH=1 to run',
      timeout: const Timeout(Duration(minutes: 5)),
      () => _run(legacy: legacy),
    );
  }
}

Future<void> _run({required bool legacy}) async {
  print(legacy ? '--- before (calling isolate)' : '--- after (off thread)');
  final dir = await Directory.systemTemp.createTemp('kanaru_session_bench');
  addTearDown(() => dir.delete(recursive: true));
  final covers = '${dir.path}/covers';
  final path = '${dir.path}/playback-session.json';
  final real = PlaybackSessionFile(path, coverDirectory: covers);
  final file = legacy
      ? _Saver((s) => _legacySave(path, s, covers), () async {})
      : _Saver(real.save, real.flush);
  final tracks = _tracks(covers);
  final order = [for (var i = 0; i < _total; i++) i];
  var session = PlaybackSession(tracks: tracks, order: order, index: 10);

  final first = await _blocked(() => file.save(session));
  print(
    'first save: longest stall ${_ms(first.longest)} ms, '
    'total stall ${_ms(first.total)} ms, wall ${_ms(first.wall)} ms',
  );

  final longest = <Duration>[];
  final total = <Duration>[];
  final wall = <Duration>[];
  for (var run = 0; run < _runs; run++) {
    session = session.withPosition(Duration(seconds: run + 1));
    final r = await _blocked(() => file.save(session));
    longest.add(r.longest);
    total.add(r.total);
    wall.add(r.wall);
  }
  print('position-only save: longest stall ${_stats(longest)}');
  print('position-only save: total stall ${_stats(total)}');
  print('position-only save: wall ${_stats(wall)}');

  longest.clear();
  total.clear();
  wall.clear();
  for (var run = 0; run < _runs; run++) {
    // A new list, as every queue edit makes one.
    final changed = _tracks(covers, suffix: ' r$run');
    session = PlaybackSession(tracks: changed, order: order, index: 10);
    final r = await _blocked(() => file.save(session));
    longest.add(r.longest);
    total.add(r.total);
    wall.add(r.wall);
  }
  print('queue-changed save: longest stall ${_stats(longest)}');
  print('queue-changed save: total stall ${_stats(total)}');
  print('queue-changed save: wall ${_stats(wall)}');

  final flushed = await _blocked(() async {
    await file.save(session.withPosition(const Duration(minutes: 1)));
    await file.flush();
  });
  print(
    'save + flush after a change of position: wall ${_ms(flushed.wall)} ms',
  );

  final size = File(path).lengthSync();
  print('file size: ${(size / 1024 / 1024).toStringAsFixed(2)} MiB');
  expect(PlaybackSessionFile(path, coverDirectory: covers).load(), isNotNull);
}
