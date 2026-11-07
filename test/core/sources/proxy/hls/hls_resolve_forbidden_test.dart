import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_playlist_loader.dart';
import 'package:kanaru/core/sources/proxy/resolved_streams.dart';
import 'package:kanaru/core/sources/proxy/stream_resolver.dart';
import 'package:kanaru/core/sources/source_models.dart';

import 'hls_loader_test_support.dart';

/// `stream.js` stand-in: the n-th run answers an HLS stream whose playlist
/// is at `/p<n>.m3u8`.
class _Runs {
  _Runs(this.rig);

  final LoaderRig rig;
  final fresh = <bool>[];
  RemoteStreamFormat format = RemoteStreamFormat.hls;
  DateTime? expiresAt;

  Future<ResolvedStream> call(
    String key, {
    required bool fresh,
    required bool Function() abandoned,
  }) async {
    this.fresh.add(fresh);
    final stream = rig.stream('/p${this.fresh.length}.m3u8');
    return ResolvedStream(
      url: stream.url,
      headers: stream.headers,
      format: format,
      expiresAt: expiresAt,
      allowed: stream.allowed,
      redirectAllowed: stream.redirectAllowed,
    );
  }
}

void main() {
  late LoaderRig rig;
  late _Runs runs;
  late ResolvedStreams streams;

  setUp(() async {
    rig = await LoaderRig.start();
    runs = _Runs(rig);
    streams = ResolvedStreams(hlsAwareResolve(runs.call, rig.loader));
    for (var n = 1; n <= 4; n++) {
      rig.serve('/p$n.m3u8', segments(n));
    }
  });
  tearDown(() => rig.close());

  Future<int> segmentCount(Future<ResolvedStream> stream) async =>
      (await stream).hls!.playlist.segments.length;

  test(
    'a progressive stream passes through untouched, nothing fetched',
    () async {
      runs.format = RemoteStreamFormat.progressive;
      final stream = await streams.begin('k', 'o').current();
      expect(stream.hls, isNull);
      expect(rig.upstream.requests, isEmpty);
    },
  );

  test(
    'an HLS stream comes back with its snapshot, shared by requests',
    () async {
      final playthrough = streams.begin('k', 'o');
      final a = playthrough.current();
      final b = playthrough.current();
      expect(identical(a, b), isTrue);
      expect((await a).hls!.rev, 1);
      expect(runs.fresh, [false]);
      expect(rig.paths, ['/p1.m3u8']);
    },
  );

  test('a 403 on the playlist goes on with the fresh resolve in the same '
      'future', () async {
    rig.upstream.forbidden.add('/p1.m3u8');
    final playthrough = streams.begin('k', 'o');
    expect(await segmentCount(playthrough.current()), 2);
    expect(runs.fresh, [false, true]);
    expect(playthrough.dead, isFalse);
    // The fresh resolve is spent: a later 403 of a request kills the item.
    final used = playthrough.current();
    await expectLater(
      playthrough.onForbidden(used),
      throwsA(isA<PlaythroughEnded>()),
    );
    expect(playthrough.dead, isTrue);
  });

  test('a 403 again kills the item with no third run', () async {
    rig.upstream.forbidden.addAll(['/p1.m3u8', '/p2.m3u8']);
    final playthrough = streams.begin('k', 'o');
    await expectLater(playthrough.current(), throwsA(isA<ResolveForbidden>()));
    expect(runs.fresh, [false, true]);
    expect(playthrough.dead, isTrue);
    expect(playthrough.failure, isA<ResolveForbidden>());
    await expectLater(playthrough.current(), throwsA(isA<PlaythroughEnded>()));
    expect(runs.fresh, hasLength(2));
  });

  test(
    'a 403 after an earlier request spent the budget is dead at once',
    () async {
      var now = DateTime.utc(2026, 11, 7, 12);
      runs.expiresAt = now.add(const Duration(minutes: 10));
      streams = ResolvedStreams(
        hlsAwareResolve(runs.call, rig.loader),
        clock: () => now,
      );
      final playthrough = streams.begin('k', 'o');
      final first = playthrough.current();
      await first;
      // A segment request got 403 and spent the fresh resolve (run 2).
      await playthrough.onForbidden(first);
      expect(runs.fresh, [false, true]);

      // The next resolve is plain (the expiry came); its playlist is refused.
      now = now.add(const Duration(minutes: 10));
      rig.upstream.forbidden.add('/p3.m3u8');
      await expectLater(
        playthrough.current(),
        throwsA(isA<ResolveForbidden>()),
      );
      expect(runs.fresh, [false, true, false]);
      expect(playthrough.dead, isTrue);
    },
  );

  test(
    'a failed playlist other than 403 kills the item with its error',
    () async {
      rig.upstream.statuses['/p1.m3u8'] = 500;
      final playthrough = streams.begin('k', 'o');
      await expectLater(playthrough.current(), throwsA(isA<ResolveFailure>()));
      expect(playthrough.dead, isTrue);
      expect(runs.fresh, [false]);
      expect(
        (playthrough.failure as ResolveFailure).reason,
        'upstream status 500',
      );
    },
  );

  test(
    'the deadline covers stream.js and both fetches, and stops a retry',
    () async {
      final slow = ResolvedStreams(
        hlsAwareResolve(runs.call, rig.loader),
        resolveDeadline: const Duration(milliseconds: 200),
      );
      rig.upstream
        ..piece = 8
        ..pause = const Duration(milliseconds: 80);
      final playthrough = slow.begin('k', 'o');
      await expectLater(
        playthrough.current(),
        throwsA(
          isA<ResolveFailure>().having((e) => e.reason, 'reason', 'timeout'),
        ),
      );
      expect(playthrough.dead, isTrue);
      expect(runs.fresh, [false]);
    },
  );

  test('the deadline also covers the fresh retry after a 403', () async {
    final slow = ResolvedStreams(
      hlsAwareResolve(runs.call, rig.loader),
      resolveDeadline: const Duration(milliseconds: 300),
    );
    // The first playlist answers 403 at once; the retry's playlist trickles.
    rig.upstream
      ..forbidden.add('/p1.m3u8')
      ..piece = 8
      ..pause = const Duration(milliseconds: 80);
    final playthrough = slow.begin('k', 'o');
    await expectLater(
      playthrough.current(),
      throwsA(
        isA<ResolveFailure>().having((e) => e.reason, 'reason', 'timeout'),
      ),
    );
    expect(runs.fresh, [false, true]);
    expect(playthrough.dead, isTrue);
  });

  test('a takeover keeps the snapshot and its rev, a new resolve after the '
      'expiry gets a new rev', () async {
    var now = DateTime.utc(2026, 11, 7, 12);
    runs.expiresAt = now.add(const Duration(minutes: 10));
    streams = ResolvedStreams(
      hlsAwareResolve(runs.call, rig.loader),
      clock: () => now,
    );
    final old = streams.begin('k', 'o');
    final first = await old.current();
    expect(first.hls!.rev, 1);

    // Opening the item again takes the resolve over: same snapshot, no fetch.
    final next = streams.begin('k', 'o');
    final again = await next.current();
    expect(identical(again.hls, first.hls), isTrue);
    expect(again.hls!.rev, 1);
    expect(runs.fresh, [false]);
    expect(rig.paths, ['/p1.m3u8']);

    // After the expiry the resolve is made again, with a new snapshot.
    now = now.add(const Duration(minutes: 10));
    final later = await next.current();
    expect(later.hls!.rev, 2);
    expect(identical(later.hls, first.hls), isFalse);
    expect(runs.fresh, [false, false]);
    expect(rig.paths, ['/p1.m3u8', '/p2.m3u8']);
  });
}
