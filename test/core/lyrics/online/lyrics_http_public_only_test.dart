import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_address_class.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http_pinned_connect.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';
import 'package:kanaru/core/lyrics/online/online_lyrics_http_factory.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_fetch_bridge.dart';
import 'package:kanaru/core/plugin_runtime/plugin_runtime.dart';

import '../plugins/repo/repo_test_support.dart';

PluginFetchCall _fetch(Uri url) => PluginFetchCall(
  method: 'GET',
  url: url,
  headers: const [],
  body: Uint8List(0),
  deadline: const Duration(seconds: 5),
  maxSends: 3,
);

void main() {
  final lrclib = LyricsProviderRegistration(LrclibProvider());
  final url = Uri.parse('https://lrclib.net/api/get?q=x');
  late TestServer plain;
  late TestServer tls;

  setUp(() async {
    plain = await TestServer.start();
    tls = await TestServer.start(secure: true);
  });
  tearDown(() async {
    await plain.close();
    await tls.close();
  });

  HttpClient guarded(FakeResolver resolver, RecordingDialer dialer) =>
      HttpClient()
        ..connectionFactory = lyricsPublicOnlyConnectionFactory(
          resolver: resolver.call,
          dialer: dialer.call,
          context: trustingTestCert(),
        );

  Future<LyricsFetchKind?> kindOf(Future<Object?> call) async {
    try {
      await call;
    } on LyricsFetchException catch (e) {
      return e.kind;
    }
    return null;
  }

  group('strict client with the public-only factory', () {
    test('a public name that resolves to loopback is blockedHost, nothing '
        'is sent', () async {
      final resolver = FakeResolver({
        'lrclib.net': [
          ['127.0.0.1'],
        ],
      });
      final dialer = RecordingDialer(plain);
      final client = guarded(resolver, dialer);
      addTearDown(() => client.close(force: true));

      expect(
        await kindOf(LyricsHttp(lrclib, client).get(url)),
        LyricsFetchKind.blockedHost,
      );
      expect(dialer.dialed, isEmpty);
      expect(plain.requests, isEmpty);
    });

    test('every non-public class is blocked, mixed answers included', () async {
      for (final answer in [
        ['10.0.0.1'],
        ['192.168.1.1'],
        ['169.254.169.254'],
        ['::1'],
        ['fd00::1'],
        ['::ffff:127.0.0.1'],
        ['0.0.0.0'],
        [fakePublicIp, '127.0.0.1'],
      ]) {
        final resolver = FakeResolver({
          'lrclib.net': [answer],
        });
        final dialer = RecordingDialer(plain);
        final client = guarded(resolver, dialer);
        addTearDown(() => client.close(force: true));
        expect(
          await kindOf(LyricsHttp(lrclib, client).get(url)),
          LyricsFetchKind.blockedHost,
          reason: '$answer',
        );
        expect(dialer.dialed, isEmpty, reason: '$answer');
      }
    });

    test('a public answer connects to the checked address and verifies the '
        'name', () async {
      tls.handler = (r) async {
        r.response.write('{"ok":true}');
        await r.response.close();
      };
      final resolver = FakeResolver({
        'lrclib.net': [
          [fakePublicIp],
        ],
      });
      final dialer = RecordingDialer(tls);
      final client = guarded(resolver, dialer);
      addTearDown(() => client.close(force: true));

      // The test certificate is for repo.example.test, not lrclib.net: the
      // handshake must fail on the name, proving the name is what is checked.
      expect(
        await kindOf(LyricsHttp(lrclib, client).get(url)),
        LyricsFetchKind.network,
      );
      expect(dialer.dialed.single.address, fakePublicIp);
      expect(tls.requests, isEmpty);
    });

    test('an IP literal is checked without a lookup', () async {
      final resolver = FakeResolver({});
      final dialer = RecordingDialer(plain);
      final client = guarded(resolver, dialer);
      addTearDown(() => client.close(force: true));
      final http = LyricsHttp.forTesting(client: client, hosts: ['127.0.0.1']);
      expect(
        await kindOf(http.get(Uri.parse('http://127.0.0.1:${plain.port}/x'))),
        LyricsFetchKind.blockedHost,
      );
      expect(resolver.lookups, isEmpty);
      expect(plain.requests, isEmpty);
    });
  });

  test('the production client refuses a loopback destination', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // A proxy in the shell environment would skip the direct path.
    final client = container.read(lyricsHttpClientProvider)
      ..findProxy = ((_) => 'DIRECT');
    final http = LyricsHttp.forTesting(client: client, hosts: ['127.0.0.1']);
    expect(
      await kindOf(http.get(Uri.parse('http://127.0.0.1:${plain.port}/x'))),
      LyricsFetchKind.blockedHost,
    );
    expect(plain.requests, isEmpty);
  });

  test('a plain client without the factory still reaches loopback', () async {
    plain.handler = (r) async {
      r.response.write('hi');
      await r.response.close();
    };
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final http = LyricsHttp.forTesting(client: client, hosts: ['127.0.0.1']);
    final response = await http.get(
      Uri.parse('http://127.0.0.1:${plain.port}/x'),
    );
    expect(response.body, 'hi');
  });

  group('plugin fetch bridge', () {
    test('a refused address is reported like a blocked host', () async {
      final resolver = FakeResolver({
        'lrclib.net': [
          ['10.1.2.3'],
        ],
      });
      final dialer = RecordingDialer(plain);
      final client = guarded(resolver, dialer);
      addTearDown(() => client.close(force: true));
      final bridge = PluginFetchBridge(LyricsHttp(lrclib, client));

      final answer = await bridge.call(_fetch(url));

      expect(answer.outcome, PluginFetchOutcome.blockedHost);
      expect(answer.sends, 1);
      expect(bridge.requests.single.blocked, isTrue);
      expect(bridge.requests.single.status, isNull);
      expect(plain.requests, isEmpty);
    });
  });

  group('lyricsPinnedConnectionFactory', () {
    test('resolves once; a later different answer is never used', () async {
      tls.handler = (r) async {
        r.response.write('ok');
        await r.response.close();
      };
      final resolver = FakeResolver({
        'repo.example.test': [
          [fakePublicIp],
          ['127.0.0.1'],
        ],
      });
      final dialer = RecordingDialer(tls);
      final checked = <List<String>>[];
      final factory = lyricsPinnedConnectionFactory(
        check: (url, addresses) =>
            checked.add([for (final a in addresses) a.address]),
        resolver: resolver.call,
        dialer: dialer.call,
        context: trustingTestCert(),
      );
      final client = HttpClient()..connectionFactory = factory;
      addTearDown(() => client.close(force: true));

      for (var i = 0; i < 2; i++) {
        final request = await client.getUrl(
          Uri.parse('https://repo.example.test:${tls.port}/'),
        );
        request.persistentConnection = false;
        final response = await request.close();
        await response.drain<void>();
        expect(response.statusCode, 200);
      }
      // Two connections, two lookups: each one connected to the answer it
      // had checked, the loopback answer was checked and dialed by itself.
      expect(checked, [
        [fakePublicIp],
        ['127.0.0.1'],
      ]);
      expect(dialer.dialed.map((a) => a.address), [fakePublicIp, '127.0.0.1']);
    });

    test('IPv4 is tried before IPv6', () async {
      tls.handler = (r) async {
        await r.response.close();
      };
      final resolver = FakeResolver({
        'repo.example.test': [
          ['2606:4700:4700::1111', fakePublicIp],
        ],
      });
      final dialer = RecordingDialer(tls);
      final client = HttpClient()
        ..connectionFactory = lyricsPinnedConnectionFactory(
          check: (url, addresses) {},
          resolver: resolver.call,
          dialer: dialer.call,
          context: trustingTestCert(),
        );
      addTearDown(() => client.close(force: true));
      final request = await client.getUrl(
        Uri.parse('https://repo.example.test:${tls.port}/'),
      );
      await (await request.close()).drain<void>();
      expect(dialer.dialed.first.address, fakePublicIp);
    });

    test('the next address is tried when one cannot be reached', () async {
      tls.handler = (r) async {
        await r.response.close();
      };
      final resolver = FakeResolver({
        'repo.example.test': [
          [fakePublicIp, '8.8.8.8'],
        ],
      });
      final dialed = <String>[];
      final client = HttpClient()
        ..connectionFactory = lyricsPinnedConnectionFactory(
          check: (url, addresses) {},
          resolver: resolver.call,
          dialer: (address, port) {
            dialed.add(address.address);
            if (address.address == fakePublicIp) {
              throw const SocketException('unreachable');
            }
            return Socket.startConnect(InternetAddress.loopbackIPv4, tls.port);
          },
          context: trustingTestCert(),
        );
      addTearDown(() => client.close(force: true));
      final request = await client.getUrl(
        Uri.parse('https://repo.example.test:${tls.port}/'),
      );
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, 200);
      expect(dialed, [fakePublicIp, '8.8.8.8']);
    });

    test('a lookup that fails or finds nothing is a network failure', () async {
      for (final resolver in <LyricsHostResolver>[
        (host) async => throw const SocketException('no dns'),
        (host) async => <InternetAddress>[],
      ]) {
        final client = HttpClient()
          ..connectionFactory = lyricsPinnedConnectionFactory(
            check: (url, addresses) => fail('must not be asked'),
            resolver: resolver,
          );
        addTearDown(() => client.close(force: true));
        await expectLater(
          client.getUrl(Uri.parse('https://repo.example.test/')),
          throwsA(isA<SocketException>()),
        );
      }
    });

    test('the class of a refusal reaches the caller', () async {
      final client = HttpClient()
        ..connectionFactory = lyricsPublicOnlyConnectionFactory(
          resolver: FakeResolver({
            'a.example': [
              ['10.0.0.1'],
            ],
          }).call,
        );
      addTearDown(() => client.close(force: true));
      await expectLater(
        client.getUrl(Uri.parse('https://a.example/')),
        throwsA(
          isA<LyricsBlockedAddressException>().having(
            (e) => e.found,
            'found',
            LyricsAddressClass.local,
          ),
        ),
      );
    });

    test('a connect that never opens ends at the connect timeout and is '
        'cancelled', () async {
      var cancelled = 0;
      final factory = lyricsPinnedConnectionFactory(
        check: (url, addresses) {},
        resolver: FakeResolver({
          'repo.example.test': [
            [fakePublicIp],
          ],
        }).call,
        dialer: (address, port) async {
          final socket = Completer<Socket>();
          return ConnectionTask.fromSocket(socket.future, () {
            cancelled++;
            socket.completeError(const SocketException('cancelled'));
          });
        },
        connectTimeout: const Duration(milliseconds: 100),
      );
      final task = await factory(
        Uri.parse('https://repo.example.test/'),
        null,
        null,
      );
      await expectLater(task.socket, throwsA(isA<SocketException>()));
      expect(cancelled, 1);
    });

    test('each address gets a share of the connect budget', () async {
      final resolver = FakeResolver({
        'repo.example.test': [
          [fakePublicIp, '8.8.8.8'],
        ],
      });
      final dialed = <String>[];
      final factory = lyricsPinnedConnectionFactory(
        check: (url, addresses) {},
        resolver: resolver.call,
        dialer: (address, port) async {
          dialed.add(address.address);
          if (address.address == fakePublicIp) {
            // Blackholed: never answers, only a cancel ends it.
            final socket = Completer<Socket>();
            return ConnectionTask.fromSocket(
              socket.future,
              () => socket.completeError(const SocketException('cancelled')),
            );
          }
          return Socket.startConnect(InternetAddress.loopbackIPv4, plain.port);
        },
        connectTimeout: const Duration(seconds: 2),
      );
      final watch = Stopwatch()..start();
      final task = await factory(
        Uri.parse('http://repo.example.test/'),
        null,
        null,
      );
      final socket = await task.socket;
      socket.destroy();
      expect(dialed, [fakePublicIp, '8.8.8.8']);
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 1800)));
    });

    test(
      'cancelling while the dial is pending stops that connection',
      () async {
        final dial = Completer<ConnectionTask<Socket>>();
        final factory = lyricsPinnedConnectionFactory(
          check: (url, addresses) {},
          resolver: FakeResolver({
            'repo.example.test': [
              [fakePublicIp],
            ],
          }).call,
          dialer: (address, port) => dial.future,
        );
        final task = await factory(
          Uri.parse('http://repo.example.test/'),
          null,
          null,
        );
        final result = expectLater(
          task.socket,
          throwsA(isA<SocketException>()),
        );
        task.cancel();

        var cancelled = 0;
        final inner = Completer<Socket>();
        dial.complete(
          ConnectionTask.fromSocket(inner.future, () {
            cancelled++;
            inner.completeError(const SocketException('cancelled'));
          }),
        );
        await result;
        expect(cancelled, 1);
      },
    );
  });

  group('behind a proxy', () {
    final target = Uri.parse('https://lrclib.net/api/get');

    LyricsConnectionFactory proxied(LyricsHostResolver resolver) =>
        lyricsPublicOnlyConnectionFactory(
          resolver: resolver,
          proxyLookupTimeout: const Duration(milliseconds: 100),
        );

    test('a name that resolves locally to a non-public address is refused, '
        'the proxy is not contacted', () async {
      final resolver = FakeResolver({
        'lrclib.net': [
          ['127.0.0.1'],
        ],
      });
      await expectLater(
        proxied(resolver.call)(target, '127.0.0.1', plain.port),
        throwsA(isA<LyricsBlockedAddressException>()),
      );
      expect(resolver.lookups, ['lrclib.net']);
      expect(plain.requests, isEmpty);
    });

    test('an IP literal is checked without a lookup', () async {
      final resolver = FakeResolver({});
      await expectLater(
        proxied(resolver.call)(
          Uri.parse('http://192.168.1.1/x'),
          '127.0.0.1',
          plain.port,
        ),
        throwsA(isA<LyricsBlockedAddressException>()),
      );
      expect(resolver.lookups, isEmpty);
    });

    test('a public answer connects to the proxy', () async {
      final resolver = FakeResolver({
        'lrclib.net': [
          [fakePublicIp],
        ],
      });
      final task = await proxied(resolver.call)(
        target,
        '127.0.0.1',
        plain.port,
      );
      final socket = await task.socket;
      expect(socket.remotePort, plain.port);
      socket.destroy();
    });

    test(
      'a failed local lookup goes through the proxy as configured',
      () async {
        for (final resolver in <LyricsHostResolver>[
          (host) async => throw const SocketException('no dns'),
          (host) async => <InternetAddress>[],
          (host) => Completer<List<InternetAddress>>().future,
        ]) {
          final task = await proxied(resolver)(target, '127.0.0.1', plain.port);
          final socket = await task.socket;
          expect(socket.remotePort, plain.port);
          socket.destroy();
        }
      },
    );

    test('a fake-ip answer (198.18.0.0/15) counts as public', () async {
      final resolver = FakeResolver({
        'lrclib.net': [
          ['198.18.0.7'],
        ],
      });
      final task = await proxied(resolver.call)(
        target,
        '127.0.0.1',
        plain.port,
      );
      (await task.socket).destroy();
    });
  });
}
