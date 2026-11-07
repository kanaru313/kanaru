import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/plugin_host_patterns.dart';
import 'package:kanaru/core/sources/proxy/source_plugin_stream_resolver.dart';
import 'package:kanaru/core/sources/proxy/stream_resolver.dart';
import 'package:kanaru/core/sources/source_models.dart';

const _id = 'plugin-abc123def456';

void main() {
  group('sourceStreamUrlAllowed', () {
    final hosts = PluginHostSet(const ['*.googlevideo.com', 'cdn.example.com']);

    test('allows https to a declared host, wildcard included', () {
      for (final url in [
        'https://rr3---sn-abc.googlevideo.com/videoplayback?sig=x',
        'https://cdn.example.com/a.webm',
        'https://CDN.example.com/a.webm',
      ]) {
        expect(
          sourceStreamUrlAllowed(Uri.parse(url), hosts),
          isTrue,
          reason: url,
        );
      }
    });

    test('the default https port is the same destination as none', () {
      // `Uri` drops it, as for a plugin's own fetch.
      expect(
        sourceStreamUrlAllowed(
          Uri.parse('https://cdn.example.com:443/a.webm'),
          hosts,
        ),
        isTrue,
      );
    });

    test('refuses another scheme, a port, user info or an undeclared host', () {
      for (final url in [
        'http://cdn.example.com/a.webm',
        'https://cdn.example.com:8443/a.webm',
        'https://cdn.example.com:80/a.webm',
        'https://user:pw@cdn.example.com/a.webm',
        'https://user@cdn.example.com/a.webm',
        'https://googlevideo.com/a',
        'https://a.b.googlevideo.com/a',
        'https://evil.example.org/a',
        'https://127.0.0.1/a',
        'https://cdn.example.com./a',
        'file:///etc/passwd',
        '/relative/path',
      ]) {
        expect(
          sourceStreamUrlAllowed(Uri.parse(url), hosts),
          isFalse,
          reason: url,
        );
      }
    });
  });

  group('SourcePluginStreamResolver', () {
    late List<({String installId, String itemId, bool fresh})> calls;
    late Uri streamUrl;
    late bool consented;
    List<String>? hosts;
    late SourceFailure? failure;
    var format = RemoteStreamFormat.progressive;

    SourcePluginStreamResolver make() => SourcePluginStreamResolver(
      stream: (installId, itemId, {required fresh, required abandoned}) async {
        calls.add((installId: installId, itemId: itemId, fresh: fresh));
        final f = failure;
        if (f != null) throw f;
        return SourceStream(
          url: streamUrl,
          headers: const {'referer': 'https://www.example.com/'},
          mimeType: 'audio/webm',
          format: format,
          expiresAt: DateTime.utc(2030),
        );
      },
      hostsOf: (installId) => installId == _id ? hosts : null,
      consented: (_) => consented,
    );

    setUp(() {
      calls = [];
      streamUrl = Uri.parse('https://rr1.googlevideo.com/videoplayback');
      consented = true;
      hosts = const ['*.googlevideo.com'];
      failure = null;
      format = RemoteStreamFormat.progressive;
    });

    Future<ResolvedStream> resolve(String key, {bool fresh = false}) =>
        make().resolve(key, fresh: fresh, abandoned: () => false);

    test('the owner of a key is its install id; malformed keys have none', () {
      final resolver = make();
      expect(resolver.ownerOf('$_id/a/b'), _id);
      for (final key in ['', _id, '$_id/', 'plugin-x/a', 'other/a']) {
        expect(resolver.ownerOf(key), isNull, reason: key);
      }
    });

    test(
      'runs stream.js with the item id (slashes kept) and the fresh flag',
      () async {
        final stream = await resolve('$_id/a/b', fresh: true);
        expect(calls.single, (installId: _id, itemId: 'a/b', fresh: true));
        expect(stream.url, streamUrl);
        expect(stream.headers, {'referer': 'https://www.example.com/'});
        expect(stream.mimeType, 'audio/webm');
        expect(stream.expiresAt, DateTime.utc(2030));
      },
    );

    test('a progressive stream keeps the progressive format', () async {
      final stream = await resolve('$_id/x');
      expect(stream.format, RemoteStreamFormat.progressive);
    });

    test('an HLS playlist passes its format through', () async {
      format = RemoteStreamFormat.hls;
      streamUrl = Uri.parse('https://rr1.googlevideo.com/list.m3u8');
      final stream = await resolve('$_id/x');
      expect(stream.format, RemoteStreamFormat.hls);
      expect(stream.url, streamUrl);
      expect(
        stream.redirectAllowed!(Uri.parse('https://rr2.googlevideo.com/a')),
        isTrue,
      );
    });

    test('an HLS playlist on an undeclared host is refused', () async {
      format = RemoteStreamFormat.hls;
      streamUrl = Uri.parse('https://evil.example.org/list.m3u8');
      await expectLater(
        resolve('$_id/x'),
        throwsA(
          isA<ResolveFailure>().having(
            (f) => f.reason,
            'reason',
            'blockedHost',
          ),
        ),
      );
    });

    test('the stream asks the consent live', () async {
      final stream = await resolve('$_id/x');
      expect(stream.allowed(), isTrue);
      consented = false;
      expect(stream.allowed(), isFalse);
    });

    test('a URL outside the plugin\'s hosts is refused', () async {
      streamUrl = Uri.parse('https://evil.example.org/a');
      await expectLater(
        resolve('$_id/x'),
        throwsA(
          isA<ResolveFailure>().having(
            (f) => f.reason,
            'reason',
            'blockedHost',
          ),
        ),
      );
    });

    test('an http URL or one with a port is refused', () async {
      for (final url in [
        'http://rr1.googlevideo.com/a',
        'https://rr1.googlevideo.com:8443/a',
      ]) {
        streamUrl = Uri.parse(url);
        await expectLater(
          resolve('$_id/x'),
          throwsA(isA<ResolveFailure>()),
          reason: url,
        );
      }
    });

    test('a plugin that is not an enabled source plugin is not run', () async {
      hosts = null;
      await expectLater(resolve('$_id/x'), throwsA(isA<ResolveFailure>()));
      await expectLater(resolve('bad/x'), throwsA(isA<ResolveFailure>()));
      expect(calls, isEmpty);
    });

    test('a failed run becomes a resolve failure', () async {
      failure = const SourceFailure(kind: SourceFailureKind.auth);
      await expectLater(
        resolve('$_id/x'),
        throwsA(
          isA<ResolveFailure>().having((f) => f.reason, 'reason', 'auth'),
        ),
      );
    });
  });
}
