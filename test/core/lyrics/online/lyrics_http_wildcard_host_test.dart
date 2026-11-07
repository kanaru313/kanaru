import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';

import '../../lyrics_translation/loopback_server.dart';
import 'counting_http_client.dart';

Future<LyricsFetchKind?> _kindOf(Future<Object?> call) async {
  try {
    await call;
  } on LyricsFetchException catch (e) {
    return e.kind;
  }
  return null;
}

LyricsHttpRequest _get(String url) =>
    LyricsHttpRequest(method: 'GET', uri: Uri.parse(url));

void main() {
  const hosts = ['*.googlevideo.com', 'www.youtube.com'];

  group('a client that may use a loopback server', () {
    late LoopbackServer server;
    late HttpClient client;
    late List<String> connected;

    setUp(() async {
      server = await LoopbackServer.start((_) => const Reply(200, 'ok'));
      connected = [];
      // Every name connects to the loopback server, so a request that is
      // allowed shows up there under the host it was made for.
      client = HttpClient()
        ..connectionFactory = (uri, proxyHost, proxyPort) {
          connected.add(uri.host);
          return Socket.startConnect(
            InternetAddress.loopbackIPv4,
            server.baseUri.port,
          );
        };
    });
    tearDown(() async {
      client.close(force: true);
      await server.close();
    });

    LyricsHttp http() => LyricsHttp.forTesting(client: client, hosts: hosts);
    String url(String host) => 'http://$host:${server.baseUri.port}/x';

    test('a host one label under a wildcard reaches the client', () async {
      final response = await http().send(
        _get(url('rr1---sn-x.googlevideo.com')),
      );
      expect(response.status, 200);
      expect(connected, ['rr1---sn-x.googlevideo.com']);
      expect(
        server.requests.single.header('host'),
        startsWith('rr1---sn-x.googlevideo.com'),
      );
    });

    test('get follows the same match', () async {
      final response = await http().get(Uri.parse(url('RR1.GoogleVideo.com')));
      expect(response.status, 200);
      expect(connected, ['rr1.googlevideo.com']);
    });

    test('a plain entry still matches exactly', () async {
      await http().send(_get(url('www.youtube.com')));
      expect(connected, ['www.youtube.com']);
    });

    test('a host the patterns do not match is blockedHost, nothing is '
        'sent', () async {
      for (final host in [
        'googlevideo.com',
        'a.b.googlevideo.com',
        'evilgooglevideo.com',
        'googlevideo.com.evil.example',
        'rr1.googlevideo.com.',
        '-a.googlevideo.com',
        '${'a' * 64}.googlevideo.com',
        'youtube.com',
        'm.youtube.com',
      ]) {
        expect(
          await _kindOf(http().send(_get(url(host)))),
          LyricsFetchKind.blockedHost,
          reason: host,
        );
        expect(
          await _kindOf(http().get(Uri.parse(url(host)))),
          LyricsFetchKind.blockedHost,
          reason: host,
        );
      }
      expect(connected, isEmpty);
      expect(server.requests, isEmpty);
    });
  });

  group('strict rules over wildcard hosts', () {
    late CountingHttpClient client;

    setUp(() => client = CountingHttpClient());

    LyricsHttp strict() => LyricsHttp.forPluginTranslate(
      hosts,
      client,
      overallTimeout: const Duration(seconds: 5),
    );

    test('an https request to a matched host goes to the client', () async {
      final kind = await _kindOf(
        strict().send(_get('https://rr1---sn-x.googlevideo.com/videoplayback')),
      );
      expect(kind, isNot(LyricsFetchKind.blockedHost));
      expect(client.opened, 1);
    });

    test('http, a port or user info on a matched host stay blocked', () async {
      for (final url in [
        'http://rr1.googlevideo.com/x',
        'https://rr1.googlevideo.com:8443/x',
        'https://user@rr1.googlevideo.com/x',
        'https://googlevideo.com/x',
        'https://a.b.googlevideo.com/x',
      ]) {
        expect(
          await _kindOf(strict().send(_get(url))),
          LyricsFetchKind.blockedHost,
          reason: url,
        );
      }
      expect(client.opened, 0);
    });
  });
}
