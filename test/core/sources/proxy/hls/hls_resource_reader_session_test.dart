import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/proxy/stream_resolver.dart';
import 'package:logging/logging.dart';

import '../proxy_test_support.dart';
import 'hls_reader_test_support.dart';

/// A media playlist of [count] 4 s segments `<dir>/seg<i>.ts`.
String inDir(String dir, int count) => [
  '#EXTM3U',
  '#EXT-X-TARGETDURATION:4',
  '#EXT-X-KEY:METHOD=AES-128,URI="$dir/key.bin"',
  for (var i = 0; i < count; i++) ...['#EXTINF:4.0,', '$dir/seg$i.ts'],
  '#EXT-X-ENDLIST',
].join('\n');

void main() {
  late ReaderRig rig;
  var now = DateTime.utc(2026, 11, 7, 12);

  Future<void> start({
    Duration stallTimeout = const Duration(seconds: 15),
  }) async {
    now = DateTime.utc(2026, 11, 7, 12);
    rig = await ReaderRig.start(
      stallTimeout: stallTimeout,
      clock: () => now,
      expiresAt: () => now.add(const Duration(minutes: 10)),
    );
    rig.loader.serve('/p1.m3u8', inDir('a', 2));
    rig.loader.serve('/p2.m3u8', inDir('b', 2));
    for (final dir in ['a', 'b']) {
      for (var i = 0; i < 2; i++) {
        rig.serveBytes(
          '/$dir/seg$i.ts',
          testBytes(100 + i + (dir == 'b' ? 1000 : 0)),
        );
      }
      rig.serveBytes('/$dir/key.bin', testBytes(16));
    }
  }

  setUp(start);
  tearDown(() => rig.close());

  group('a 403', () {
    test('on a segment: fresh resolve, served from the new snapshot', () async {
      rig.upstream.forbidden.add('/a/seg0.ts');
      final answer = await rig.open('hls/1/s0.ts');
      expect(answer.status, 200);
      expect(await bodyOf(answer), testBytes(1100));
      expect(rig.runs, [false, true]);
      expect(rig.paths, ['/p1.m3u8', '/a/seg0.ts', '/p2.m3u8', '/b/seg0.ts']);
      // The old rev still maps to the new snapshot, with no new resolve.
      final next = await rig.open('hls/1/s1.ts');
      expect(await bodyOf(next), testBytes(1101));
      expect(rig.runs, [false, true]);
    });

    test('on a key is handled the same way', () async {
      rig.upstream.forbidden.add('/a/key.bin');
      final answer = await rig.open('hls/1/k0.key');
      expect(answer.status, 200);
      expect(await bodyOf(answer), testBytes(16));
      expect(rig.runs, [false, true]);
      expect(rig.paths.last, '/b/key.bin');
    });

    test('with another layout after the resolve: 502, not dead', () async {
      rig.loader.serve('/p2.m3u8', inDir('b', 3));
      rig.serveBytes('/b/seg2.ts', testBytes(1000));
      rig.upstream.forbidden.add('/a/seg0.ts');
      final answer = await rig.open('hls/1/s0.ts');
      expect(answer.status, 502);
      expect(answer.body, isNull);
      expect(rig.playthrough.dead, isFalse);
      // The new snapshot is served under its own rev.
      final next = await rig.open('hls/2/s2.ts');
      expect(next.status, 200);
      expect(await bodyOf(next), testBytes(1000));
      expect(rig.runs, [false, true]);
    });

    test('twice: 502, the item is dead and the next request fails at '
        'once', () async {
      rig.upstream.forbidden.addAll(['/a/seg0.ts', '/b/seg0.ts']);
      final answer = await rig.open('hls/1/s0.ts');
      expect(answer.status, 502);
      expect(rig.playthrough.dead, isTrue);
      final runs = rig.runs.length;
      final requests = rig.paths.length;
      expect((await rig.open('hls/1/s1.ts')).status, 502);
      expect((await rig.open('hls/2/s1.ts')).status, 502);
      expect(rig.runs, hasLength(runs));
      expect(rig.paths, hasLength(requests));
    });

    test('three across an expiry: 502, dead, no error escapes', () async {
      rig.loader.serve('/p3.m3u8', inDir('c', 2));
      for (var i = 0; i < 2; i++) {
        rig.serveBytes('/c/seg$i.ts', testBytes(2000 + i));
      }
      rig.serveBytes('/c/key.bin', testBytes(16));
      expect(await bodyOf(await rig.open('hls/1/s0.ts')), testBytes(100));
      rig.upstream.forbidden.addAll(['/a/seg1.ts', '/b/seg1.ts', '/c/seg1.ts']);
      final errors = <Object>[];
      final status = Completer<int>();
      runZonedGuarded(() {
        // The request holds the first resolve; another one replaces it
        // (the validity ended) before the 403 comes back.
        final answer = rig.open('hls/1/s1.ts');
        now = now.add(const Duration(minutes: 10));
        rig.playthrough.current();
        answer.then((a) => status.complete(a.status));
      }, (error, _) => errors.add(error));
      expect(await status.future, 502);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(rig.runs, [false, false, true]);
      expect(rig.playthrough.dead, isTrue);
      expect(errors, isEmpty);
    });

    test('after the budget was spent elsewhere: dead at once', () async {
      // A first 403 on a key spent the fresh resolve.
      rig.upstream.forbidden.add('/a/key.bin');
      expect((await rig.open('hls/1/k0.key')).status, 200);
      rig.upstream.forbidden.add('/b/seg1.ts');
      expect((await rig.open('hls/1/s1.ts')).status, 502);
      expect(rig.playthrough.dead, isTrue);
      expect(rig.runs, [false, true]);
    });
  });

  test('a request after the validity ended starts one plain resolve, and '
      'is served through the layout', () async {
    expect(await bodyOf(await rig.open('hls/1/s0.ts')), testBytes(100));
    now = now.add(const Duration(minutes: 10));
    final answer = await rig.open('hls/1/s1.ts');
    expect(answer.status, 200);
    expect(await bodyOf(answer), testBytes(1101));
    expect(rig.runs, [false, false]);
    expect(await bodyOf(await rig.open('hls/1/s0.ts')), testBytes(1100));
    expect(rig.runs, [false, false]);
  });

  test('consent withdrawn between two segments: 502, nothing sent '
      'upstream', () async {
    expect((await rig.open('hls/1/s0.ts')).status, 200);
    final requests = rig.paths.length;
    rig.allowed = false;
    expect((await rig.open('hls/1/s1.ts')).status, 502);
    expect((await rig.open('hls/1/k0.key')).status, 502);
    expect(rig.paths, hasLength(requests));
  });

  group('the body', () {
    test('the client leaving cancels the upstream read', () async {
      rig.serveBytes('/a/seg0.ts', testBytes(200000));
      rig.upstream
        ..piece = 1000
        ..pause = const Duration(milliseconds: 5);
      final answer = await rig.open('hls/1/s0.ts');
      final cut = rig.upstream.cuts.first.timeout(const Duration(seconds: 5));
      final first = Completer<void>();
      final sub = answer.body!.listen((_) {
        if (!first.isCompleted) first.complete();
      });
      await first.future;
      await sub.cancel();
      await cut;
      expect(rig.upstream.cutShort, 1);
      expect(await answer.done, lessThan(200000));
    });

    test('abort before the body is listened drops the upstream', () async {
      rig.serveBytes('/a/seg0.ts', testBytes(200000));
      rig.upstream
        ..piece = 1000
        ..pause = const Duration(milliseconds: 5);
      final answer = await rig.open('hls/1/s0.ts');
      final cut = rig.upstream.cuts.first.timeout(const Duration(seconds: 5));
      answer.abort();
      await cut;
      expect(rig.upstream.cutShort, 1);
      expect(await answer.done, 0);
      expect(await bodyOf(answer), isEmpty);
    });

    test('a key aborted before it is listened ends without error', () async {
      final answer = await rig.open('hls/1/k0.key');
      answer.abort();
      expect(await answer.done, 0);
    });

    test('abort ends the body and drops the upstream', () async {
      rig.serveBytes('/a/seg0.ts', testBytes(200000));
      rig.upstream
        ..piece = 1000
        ..pause = const Duration(milliseconds: 5);
      final answer = await rig.open('hls/1/s0.ts');
      final cut = rig.upstream.cuts.first.timeout(const Duration(seconds: 5));
      final received = <int>[];
      final ended = Completer<void>();
      answer.body!.listen(received.addAll, onDone: ended.complete);
      await until(() => received.isNotEmpty);
      answer.abort();
      await ended.future;
      await cut;
      expect(received.length, lessThan(200000));
    });
  });

  group('a stalled upstream', () {
    setUp(() async {
      await rig.close();
      await start(stallTimeout: const Duration(seconds: 1));
    });

    test('ends the body after the stall timeout', () async {
      rig.serveBytes('/a/seg0.ts', testBytes(1000));
      rig.upstream
        ..piece = 100
        ..pause = const Duration(seconds: 3);
      final answer = await rig.open('hls/1/s0.ts');
      final clock = Stopwatch()..start();
      final body = await bodyOf(answer);
      expect(body, testBytes(100));
      expect(clock.elapsed, lessThan(const Duration(seconds: 3)));
      expect(await answer.done, 100);
    });
  });

  test('the log names the failure, never a URL, header or key', () async {
    final lines = <String>[];
    Logger.root.level = Level.ALL;
    final sub = Logger.root.onRecord.listen((r) => lines.add(r.message));
    addTearDown(sub.cancel);
    rig.serveBytes('/a/key.bin', testBytes(17));
    expect((await rig.open('hls/1/k0.key')).status, 502);
    rig.allowed = false;
    expect((await rig.open('hls/1/s0.ts')).status, 502);
    rig.allowed = true;
    rig.upstream.forbidden.addAll(['/a/seg1.ts', '/b/seg1.ts']);
    expect((await rig.open('hls/1/s1.ts')).status, 502);

    expect(lines, contains('$testInstallId hls key failed: hls badKey'));
    expect(
      lines,
      contains('$testInstallId hls segment failed: consent withdrawn'),
    );
    expect(lines.where((l) => l.startsWith(testInstallId)), isNotEmpty);
    for (final line in lines) {
      expect(
        line,
        isNot(
          matches(RegExp('127\\.0\\.0\\.1|seg\\d|key\\.bin|x-plugin|m3u8')),
        ),
      );
    }
  });

  test('a dead item says why with the resolve failure', () async {
    rig.loader.serve('/p1.m3u8', 'not a playlist');
    expect((await rig.open('hls/1/s0.ts')).status, 502);
    expect(rig.playthrough.failure, isA<ResolveFailure>());
    expect(rig.playthrough.dead, isTrue);
  });
}
