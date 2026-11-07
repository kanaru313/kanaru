import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/hls/hls_refusal.dart';
import 'package:kanaru/core/sources/proxy/hls/hls_resolve_failure.dart';
import 'package:kanaru/core/sources/proxy/stream_resolver.dart';

import 'hls_loader_test_support.dart';

void main() {
  late LoaderRig rig;
  setUp(() async => rig = await LoaderRig.start());
  tearDown(() => rig.close());

  group('fetch failures', () {
    test(
      '403 throws ResolveForbidden, on the master and on the media',
      () async {
        rig.upstream.statuses['/pl.m3u8'] = HttpStatus.forbidden;
        await expectLater(rig.load(), throwsA(isA<ResolveForbidden>()));

        rig.serve(
          '/master.m3u8',
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="mp4a.40.2"\na.m3u8',
        );
        rig.upstream.statuses['/a.m3u8'] = HttpStatus.forbidden;
        await expectLater(
          rig.load('/master.m3u8'),
          throwsA(isA<ResolveForbidden>()),
        );
      },
    );

    for (final status in [404, 500]) {
      test('$status fails the resolve with a plain ResolveFailure', () async {
        rig.upstream.statuses['/pl.m3u8'] = status;
        await expectLater(
          rig.load(),
          throwsA(
            isA<ResolveFailure>()
                .having((e) => e, 'not hls', isNot(isA<HlsResolveFailure>()))
                .having((e) => e.reason, 'reason', 'upstream status $status'),
          ),
        );
      });
    }

    test('a network error fails the resolve without the URL', () async {
      final stream = rig.stream();
      await rig.upstream.close();
      await expectLater(
        rig.loader.load('k', stream, abandoned: () => false),
        throwsA(
          isA<ResolveFailure>().having(
            (e) => e.reason,
            'reason',
            isNot(contains('127.0.0.1')),
          ),
        ),
      );
    });

    test('a body over 4 MiB is tooLarge', () async {
      rig.upstream.bodies['/pl.m3u8'] = List.filled(4 * 1024 * 1024 + 1, 0x23);
      await expectLater(rig.load(), refusedWith(HlsRefusalKind.tooLarge));
    });

    test('a slow body is tooLarge', () async {
      await rig.close();
      rig = await LoaderRig.start(
        bodyTimeout: const Duration(milliseconds: 150),
      );
      rig.serve('/pl.m3u8', segments(50));
      rig.upstream
        ..piece = 16
        ..pause = const Duration(milliseconds: 100);
      await expectLater(rig.load(), refusedWith(HlsRefusalKind.tooLarge));
    });

    test('a redirect the stream does not allow fails the resolve', () async {
      rig.upstream.redirected.add('/pl.m3u8');
      final stream = rig.stream();
      final bare = ResolvedStream(
        url: stream.url,
        headers: stream.headers,
        format: stream.format,
        allowed: stream.allowed,
      );
      await expectLater(
        rig.loader.load('k', bare, abandoned: () => false),
        throwsA(isA<ResolveFailure>()),
      );
    });
  });

  group('consent and abandonment', () {
    test('consent withdrawn before the fetch: nothing is sent', () async {
      rig.serve('/pl.m3u8', segments(1));
      rig.allowed = false;
      await expectLater(rig.load(), throwsA(isA<ResolveFailure>()));
      expect(rig.upstream.requests, isEmpty);
    });

    test('abandoned between master and media stops the second fetch', () async {
      rig.serve(
        '/master.m3u8',
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="mp4a.40.2"\na.m3u8',
      );
      rig.serve('/a.m3u8', segments(1));
      final stream = rig.stream('/master.m3u8');
      var asked = 0;
      await expectLater(
        rig.loader.load('k', stream, abandoned: () => ++asked > 1),
        throwsA(isA<ResolveFailure>()),
      );
      expect(rig.paths, ['/master.m3u8']);
    });

    test('abandoned from the start sends nothing', () async {
      rig.serve('/pl.m3u8', segments(1));
      await expectLater(
        rig.load('/pl.m3u8', () => true),
        throwsA(isA<ResolveFailure>()),
      );
      expect(rig.upstream.requests, isEmpty);
    });
  });
}
