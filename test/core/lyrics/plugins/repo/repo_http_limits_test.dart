import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_http.dart';

import 'repo_test_support.dart';

/// A dialer whose connection never completes until it is cancelled.
class HangingDialer {
  int dialed = 0;
  int cancelled = 0;

  Future<ConnectionTask<Socket>> call(InternetAddress address, int port) async {
    dialed++;
    final socket = Completer<Socket>();
    return ConnectionTask.fromSocket(socket.future, () {
      cancelled++;
      if (!socket.isCompleted) {
        socket.completeError(const SocketException('cancelled'));
      }
    });
  }
}

void main() {
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

  Future<RepoFetchException> failure(Future<Object?> call) async {
    try {
      await call;
    } on RepoFetchException catch (e) {
      return e;
    }
    fail('expected a RepoFetchException');
  }

  Future<void> redirect(HttpRequest r, String location) async {
    r.response.statusCode = 302;
    r.response.headers.set(HttpHeaders.locationHeader, location);
    await r.response.close();
  }

  FakeResolver publicName() => FakeResolver({
    'repo.example.test': [
      [fakePublicIp],
    ],
  });

  group('timeouts', () {
    test('a connection that never opens ends at the connect timeout and is '
        'cancelled', () async {
      final dialer = HangingDialer();
      final watch = Stopwatch()..start();
      final e = await failure(
        RepoHttp(
          resolver: publicName().call,
          dialer: dialer.call,
          connectTimeout: const Duration(milliseconds: 100),
        ).fetchCatalog(Uri.parse('https://repo.example.test/c.json')),
      );
      expect(e.kind, RepoFetchErrorKind.network);
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
      expect(dialer.dialed, 1);
      expect(dialer.cancelled, greaterThanOrEqualTo(1));
    });

    test('the total timeout stops work: a lookup that ends late starts no '
        'connection', () async {
      final late = Completer<List<InternetAddress>>();
      final dialer = HangingDialer();
      final e = await failure(
        RepoHttp(
          resolver: (host) => late.future,
          dialer: dialer.call,
          totalTimeout: const Duration(milliseconds: 100),
        ).fetchCatalog(Uri.parse('https://repo.example.test/c.json')),
      );
      expect(e.kind, RepoFetchErrorKind.network);

      late.complete([InternetAddress(fakePublicIp)]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(dialer.dialed, 0);
      expect(plain.requests, isEmpty);
      expect(tls.requests, isEmpty);
    });

    test('the total timeout destroys the connection of a request in '
        'flight', () async {
      // A server that accepts and never answers; it sees the client leave.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());
      final closed = Completer<void>();
      server.listen((socket) {
        socket.listen(
          (_) {},
          onDone: () {
            if (!closed.isCompleted) closed.complete();
          },
          onError: (_) {
            if (!closed.isCompleted) closed.complete();
          },
        );
      });
      final e = await failure(
        RepoHttp(totalTimeout: const Duration(milliseconds: 300))
            .fetchCatalog(Uri.parse('http://127.0.0.1:${server.port}/c.json')),
      );
      expect(e.kind, RepoFetchErrorKind.network);
      await closed.future.timeout(const Duration(seconds: 5));
    });

    test('no hop starts after the total timeout', () async {
      var hops = 0;
      plain.handler = (r) async {
        hops++;
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await redirect(r, '/next');
      };
      final e = await failure(
        RepoHttp(totalTimeout: const Duration(milliseconds: 200))
            .fetchCatalog(Uri.parse('http://127.0.0.1:${plain.port}/c.json')),
      );
      expect(e.kind, RepoFetchErrorKind.network);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(hops, lessThanOrEqualTo(2));
      expect(plain.requests.length, hops);
    });
  });

  group('class of a catalog along its redirects', () {
    /// Hops to a loopback address go to [plain], hops to the fake public
    /// address go to [tls].
    RepoHttp client(FakeResolver resolver) => RepoHttp(
      resolver: resolver.call,
      securityContext: trustingTestCert(),
      dialer: (address, port) => Socket.startConnect(
        InternetAddress.loopbackIPv4,
        address.address == fakePublicIp ? tls.port : plain.port,
      ),
    );

    test('a local catalog that redirects to a public host is public', () async {
      plain.handler = (r) =>
          redirect(r, 'https://repo.example.test:${tls.port}/c.json');
      tls.handler = (r) async {
        r.response.add([7]);
        await r.response.close();
      };
      final response = await client(publicName())
          .fetchCatalog(Uri.parse('http://127.0.0.1:${plain.port}/c.json'));
      expect(response.bytes, [7]);
      expect(response.kind, RepoAddressKind.public);
    });

    test('after a public hop the chain may not return to a local '
        'address', () async {
      plain.handler = (r) =>
          redirect(r, 'https://repo.example.test:${tls.port}/c.json');
      tls.handler = (r) => redirect(r, 'http://127.0.0.1:${plain.port}/x');
      final e = await failure(
        client(publicName())
            .fetchCatalog(Uri.parse('http://127.0.0.1:${plain.port}/c.json')),
      );
      expect(e.kind, RepoFetchErrorKind.blockedAddress);
      expect(e.reason, RepoAddressProblem.localFromPublic);
      expect(plain.requests, hasLength(1));
    });

    test('a catalog that stays local stays local', () async {
      plain.handler = (r) async {
        r.response.add([1]);
        await r.response.close();
      };
      final response = await client(publicName())
          .fetchCatalog(Uri.parse('http://127.0.0.1:${plain.port}/c.json'));
      expect(response.kind, RepoAddressKind.local);
    });
  });
}
