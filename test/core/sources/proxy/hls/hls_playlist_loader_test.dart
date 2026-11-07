import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/sources/hls/hls_refusal.dart';
import 'package:kanaru/core/sources/proxy/stream_resolver.dart';

import 'hls_loader_test_support.dart';

void main() {
  late LoaderRig rig;
  setUp(() async => rig = await LoaderRig.start());
  tearDown(() => rig.close());

  group('media playlist', () {
    test(
      'is fetched with the plugin headers, no range, base = its URL',
      () async {
        rig.serve('/a/pl.m3u8', segments(2));
        final stream = await rig.load('/a/pl.m3u8');
        final playlist = stream.hls!.playlist;
        expect(playlist.segments.map((s) => s.uri.path), [
          '/a/seg0.ts',
          '/a/seg1.ts',
        ]);
        final request = rig.upstream.requests.single;
        expect(request.range, isNull);
        expect(request.headers.value('x-plugin'), 'yes');
        expect(request.headers.value('accept-encoding'), 'identity');
      },
    );

    test('each load gets a new rev, remembered with the item key', () async {
      rig.serve('/pl.m3u8', segments(1));
      final first = (await rig.load()).hls!;
      final second = (await rig.load()).hls!;
      expect([first.rev, second.rev], [1, 2]);
      expect(first.layout, second.layout);
      expect(rig.loader.memory.layoutOf('k', 1), first.layout);
      expect(rig.loader.memory.layoutOf('other', 1), isNull);
    });

    test('relative URIs resolve against the redirect target', () async {
      rig.serve('/moved/pl.m3u8', segments(1));
      rig.upstream.redirected.add('/pl.m3u8');
      rig.upstream.redirectTo['/pl.m3u8'] = '/moved/pl.m3u8';
      final stream = await rig.load();
      expect(stream.hls!.playlist.segments.single.uri.path, '/moved/seg0.ts');
    });

    test('an absolute URI on another declared host passes', () async {
      rig.serve(
        '/pl.m3u8',
        '#EXTM3U\n#EXTINF:4,\nhttps://cdn2.example.com/x.ts\n#EXT-X-ENDLIST',
      );
      final stream = await rig.load();
      expect(stream.hls!.playlist.segments.single.uri.host, 'cdn2.example.com');
    });

    for (final (name, uri) in [
      ('an undeclared host', 'https://evil.example.com/x.ts'),
      ('a data: URI', 'data:audio/mpeg;base64,AAAA'),
      ('a file: URI', 'file:///etc/passwd'),
    ]) {
      test('$name refuses the whole playlist as blockedHost', () async {
        rig.serve(
          '/pl.m3u8',
          '#EXTM3U\n#EXTINF:4,\nseg0.ts\n#EXTINF:4,\n$uri\n#EXT-X-ENDLIST',
        );
        await expectLater(rig.load(), refusedWith(HlsRefusalKind.blockedHost));
      });
    }

    test('a key or an init URI on an undeclared host is blockedHost', () async {
      for (final tag in [
        '#EXT-X-KEY:METHOD=AES-128,URI="https://evil.example.com/k"',
        '#EXT-X-MAP:URI="https://evil.example.com/init.mp4"',
      ]) {
        rig.serve('/pl.m3u8', segments(1, extra: [tag]));
        await expectLater(rig.load(), refusedWith(HlsRefusalKind.blockedHost));
      }
    });

    test('the key an init section is read under is checked too', () async {
      rig.serve(
        '/pl.m3u8',
        segments(
          1,
          extra: [
            '#EXT-X-KEY:METHOD=AES-128,URI="https://evil.example.com/k"',
            '#EXT-X-MAP:URI="init.mp4"',
            '#EXT-X-KEY:METHOD=NONE',
          ],
        ),
      );
      await expectLater(rig.load(), refusedWith(HlsRefusalKind.blockedHost));
    });

    test(
      'a stream without a redirect rule refuses every derived URL',
      () async {
        rig.serve('/pl.m3u8', segments(1));
        final stream = rig.stream();
        final bare = ResolvedStream(
          url: stream.url,
          headers: stream.headers,
          format: stream.format,
          allowed: stream.allowed,
        );
        await expectLater(
          rig.loader.load('k', bare, abandoned: () => false),
          refusedWith(HlsRefusalKind.blockedHost),
        );
      },
    );

    test('a live playlist is refused as live', () async {
      rig.serve('/pl.m3u8', '#EXTM3U\n#EXTINF:4,\nseg0.ts');
      await expectLater(rig.load(), refusedWith(HlsRefusalKind.live));
    });
  });

  group('master playlist', () {
    const master =
        '#EXTM3U\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=900000,CODECS="mp4a.40.2"\naudio.m3u8\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=2000000,CODECS="avc1.4d401f,mp4a.40.2"\nv.m3u8';

    test(
      'the audio-only variant is fetched, one hop, base = its URL',
      () async {
        rig.serve('/m/master.m3u8', master);
        rig.serve('/m/audio.m3u8', segments(1));
        final stream = await rig.load('/m/master.m3u8');
        expect(rig.paths, ['/m/master.m3u8', '/m/audio.m3u8']);
        expect(stream.hls!.playlist.segments.single.uri.path, '/m/seg0.ts');
      },
    );

    test('audio in an EXT-X-MEDIA group is used', () async {
      rig.serve(
        '/master.m3u8',
        '#EXTM3U\n'
            '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",DEFAULT=YES,URI="aud.m3u8"\n'
            '#EXT-X-STREAM-INF:BANDWIDTH=2000000,CODECS="avc1.4d401f",AUDIO="a"\nv.m3u8',
      );
      rig.serve('/aud.m3u8', segments(1));
      await rig.load('/master.m3u8');
      expect(rig.paths, ['/master.m3u8', '/aud.m3u8']);
    });

    test('only video variants is noAudio', () async {
      rig.serve(
        '/master.m3u8',
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="avc1.4d401f"\nv.m3u8',
      );
      await expectLater(
        rig.load('/master.m3u8'),
        refusedWith(HlsRefusalKind.noAudio),
      );
      expect(rig.paths, ['/master.m3u8']);
    });

    test('a master behind a master is invalid', () async {
      rig.serve('/master.m3u8', master);
      rig.serve('/audio.m3u8', master);
      await expectLater(
        rig.load('/master.m3u8'),
        refusedWith(HlsRefusalKind.invalid),
      );
    });

    test('the chosen variant on an undeclared host is blockedHost', () async {
      rig.serve(
        '/master.m3u8',
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,CODECS="mp4a.40.2"\n'
            'https://evil.example.com/a.m3u8',
      );
      await expectLater(
        rig.load('/master.m3u8'),
        refusedWith(HlsRefusalKind.blockedHost),
      );
      expect(rig.paths, ['/master.m3u8']);
    });
  });
}
