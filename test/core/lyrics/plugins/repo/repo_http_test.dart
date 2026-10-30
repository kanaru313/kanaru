import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_http.dart';

import 'repo_test_support.dart';

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

  Future<void> respond(
    HttpRequest r,
    List<int> body, {
    int status = 200,
  }) async {
    r.response.statusCode = status;
    r.response.add(body);
    await r.response.close();
  }

  Future<void> redirect(HttpRequest r, String location) async {
    r.response.statusCode = 302;
    r.response.headers.set(HttpHeaders.locationHeader, location);
    await r.response.close();
  }

  Future<RepoFetchException> failure(Future<Object?> call) async {
    try {
      await call;
    } on RepoFetchException catch (e) {
      return e;
    }
    fail('expected a RepoFetchException');
  }

  /// A client for a public repository: names resolve through [resolver] and
  /// every connection goes to the TLS test server, which the client trusts.
  (RepoHttp, RecordingDialer) publicClient(FakeResolver resolver) {
    final dialer = RecordingDialer(tls);
    return (
      RepoHttp(
        resolver: resolver.call,
        dialer: dialer.call,
        securityContext: trustingTestCert(),
      ),
      dialer,
    );
  }

  group('local repository over plain http', () {
    test('fetches a catalog by IP literal, sends the app User-Agent', () async {
      plain.handler = (r) => respond(r, [1, 2, 3]);
      final url = Uri.parse('http://127.0.0.1:${plain.port}/plugins.json');
      final response = await RepoHttp().fetchCatalog(url);
      expect(response.bytes, [1, 2, 3]);
      expect(response.kind, RepoAddressKind.local);
      expect(response.finalUrl, url);
      expect(plain.userAgents.single, startsWith('Kanaru/'));
      expect(plain.userAgents.single, contains('github.com/kanaru313/kanaru'));
    });

    test(
      'a private-range http catalog is allowed (resolved by name)',
      () async {
        plain.handler = (r) => respond(r, [9]);
        final resolver = FakeResolver({
          'nas.lan': [
            ['192.168.1.5'],
          ],
        });
        final dialer = RecordingDialer(plain);
        final response = await RepoHttp(
          resolver: resolver.call,
          dialer: dialer.call,
        ).fetchCatalog(Uri.parse('http://nas.lan:8765/plugins.json'));
        expect(response.kind, RepoAddressKind.local);
        expect(dialer.dialed.single.address, '192.168.1.5');
        expect(plain.hosts.single, 'nas.lan:8765');
      },
    );

    test('http://example.com/x.json resolving public is refused', () async {
      final resolver = FakeResolver({
        'example.com': [
          [fakePublicIp],
        ],
      });
      final dialer = RecordingDialer(plain);
      final e = await failure(
        RepoHttp(
          resolver: resolver.call,
          dialer: dialer.call,
        ).fetchCatalog(Uri.parse('http://example.com/x.json')),
      );
      expect(e.kind, RepoFetchErrorKind.blockedAddress);
      expect(e.reason, RepoAddressProblem.publicNeedsHttps);
      expect(dialer.dialed, isEmpty);
    });

    test('a local catalog may point to another local address', () async {
      plain.handler = (r) => respond(r, [7]);
      final response = await RepoHttp().fetchZip(
        Uri.parse('http://127.0.0.1:${plain.port}/a.zip'),
        catalogKind: RepoAddressKind.local,
      );
      expect(response.bytes, [7]);
    });
  });

  group('public repository over https', () {
    test('verifies the name, reaches the checked address only', () async {
      tls.handler = (r) => respond(r, [4, 5]);
      final resolver = FakeResolver({
        'repo.example.test': [
          [fakePublicIp],
        ],
      });
      final (client, dialer) = publicClient(resolver);
      final response = await client.fetchCatalog(
        Uri.parse('https://repo.example.test:${tls.port}/plugins.json'),
      );
      expect(response.bytes, [4, 5]);
      expect(response.kind, RepoAddressKind.public);
      expect(resolver.lookups, ['repo.example.test']);
      expect(dialer.dialed.single.address, fakePublicIp);
      expect(tls.hosts.single, 'repo.example.test:${tls.port}');
    });

    test('the certificate must match the name asked for', () async {
      tls.handler = (r) => respond(r, [1]);
      // The certificate is for repo.example.test and localhost only.
      final resolver = FakeResolver({
        'other.example.test': [
          [fakePublicIp],
        ],
      });
      final (client, _) = publicClient(resolver);
      final e = await failure(
        client.fetchCatalog(Uri.parse('https://other.example.test/c.json')),
      );
      expect(e.kind, RepoFetchErrorKind.network);
      expect(tls.requests, isEmpty);
    });

    test('a self-signed server fails without a trusted context', () async {
      tls.handler = (r) => respond(r, [1]);
      final resolver = FakeResolver({
        'repo.example.test': [
          [fakePublicIp],
        ],
      });
      final dialer = RecordingDialer(tls);
      final e = await failure(
        RepoHttp(
          resolver: resolver.call,
          dialer: dialer.call,
        ).fetchCatalog(Uri.parse('https://repo.example.test/plugins.json')),
      );
      expect(e.kind, RepoFetchErrorKind.network);
      expect(tls.requests, isEmpty);
    });

    test('a self-signed loopback IP server fails without trust', () async {
      tls.handler = (r) => respond(r, [1]);
      final e = await failure(
        RepoHttp().fetchCatalog(
          Uri.parse('https://127.0.0.1:${tls.port}/plugins.json'),
        ),
      );
      expect(e.kind, RepoFetchErrorKind.network);
      expect(tls.requests, isEmpty);
    });

    test('a public catalog may not point to a local address', () async {
      final resolver = FakeResolver({
        'rebind.example.test': [
          ['127.0.0.1'],
        ],
      });
      final e = await failure(
        RepoHttp(resolver: resolver.call).fetchZip(
          Uri.parse('https://rebind.example.test/a.zip'),
          catalogKind: RepoAddressKind.public,
        ),
      );
      expect(e.kind, RepoFetchErrorKind.blockedAddress);
      expect(e.reason, RepoAddressProblem.localFromPublic);
      expect(plain.requests, isEmpty);
    });

    test('a public catalog may not point to a local literal or http', () async {
      for (final (url, reason) in [
        ('http://10.0.0.2/a.zip', RepoAddressProblem.localFromPublic),
        ('https://[::1]/a.zip', RepoAddressProblem.localFromPublic),
        ('http://cdn.example.test/a.zip', RepoAddressProblem.publicNeedsHttps),
      ]) {
        final e = await failure(
          RepoHttp(resolver: FakeResolver({}).call)
              .fetchZip(Uri.parse(url), catalogKind: RepoAddressKind.public),
        );
        expect(e.reason, reason, reason: url);
      }
    });

    test('a mixed answer is refused and nothing is dialed', () async {
      final resolver = FakeResolver({
        'repo.example.test': [
          [fakePublicIp, '10.0.0.1'],
        ],
      });
      final (client, dialer) = publicClient(resolver);
      final e = await failure(
        client.fetchCatalog(Uri.parse('https://repo.example.test/c.json')),
      );
      expect(e.reason, RepoAddressProblem.mixedAddresses);
      expect(dialer.dialed, isEmpty);
    });

    test('DNS rebinding: only the checked address is connected', () async {
      tls.handler = (r) => respond(r, [1]);
      // The second answer would be loopback; it must never be asked for.
      final resolver = FakeResolver({
        'repo.example.test': [
          [fakePublicIp],
          ['127.0.0.1'],
        ],
      });
      final (client, dialer) = publicClient(resolver);
      final response = await client.fetchCatalog(
        Uri.parse('https://repo.example.test:${tls.port}/c.json'),
      );
      expect(response.kind, RepoAddressKind.public);
      expect(resolver.lookups, hasLength(1));
      expect(dialer.dialed.map((a) => a.address), [fakePublicIp]);
    });

    test('rebinding between hops: the second hop is checked again', () async {
      var hit = 0;
      tls.handler = (r) {
        hit++;
        return redirect(r, 'https://repo.example.test:${tls.port}/next');
      };
      final resolver = FakeResolver({
        'repo.example.test': [
          [fakePublicIp],
          ['127.0.0.1'],
        ],
      });
      final (client, dialer) = publicClient(resolver);
      final e = await failure(
        client.fetchCatalog(
          Uri.parse('https://repo.example.test:${tls.port}/c.json'),
        ),
      );
      // The second hop resolved to loopback, which a public catalog may not
      // reach.
      expect(e.reason, RepoAddressProblem.localFromPublic);
      expect(hit, 1);
      expect(dialer.dialed, hasLength(1));
    });
  });

  group('redirects', () {
    test('three are followed, relative locations resolved', () async {
      plain.handler = (r) {
        final path = r.uri.path;
        return switch (path) {
          '/c.json' => redirect(r, '/a'),
          '/a' => redirect(r, 'b'),
          '/b' => redirect(r, 'http://127.0.0.1:${plain.port}/final.json'),
          _ => respond(r, [42]),
        };
      };
      final response = await RepoHttp().fetchCatalog(
        Uri.parse('http://127.0.0.1:${plain.port}/c.json'),
      );
      expect(response.bytes, [42]);
      expect(response.finalUrl.path, '/final.json');
      expect(plain.requests, hasLength(4));
    });

    test('the fourth is refused', () async {
      plain.handler = (r) => redirect(r, '/again');
      final e = await failure(
        RepoHttp().fetchCatalog(
          Uri.parse('http://127.0.0.1:${plain.port}/c.json'),
        ),
      );
      expect(e.kind, RepoFetchErrorKind.network);
      expect(plain.requests, hasLength(4));
    });

    test(
      'a redirect from a public catalog to a local address is refused',
      () async {
        tls.handler = (r) => redirect(r, 'http://127.0.0.1:${plain.port}/x');
        final resolver = FakeResolver({
          'repo.example.test': [
            [fakePublicIp],
          ],
        });
        final (client, dialer) = publicClient(resolver);
        final e = await failure(
          client.fetchCatalog(
            Uri.parse('https://repo.example.test:${tls.port}/c.json'),
          ),
        );
        expect(e.kind, RepoFetchErrorKind.blockedAddress);
        expect(e.reason, RepoAddressProblem.localFromPublic);
        expect(plain.requests, isEmpty);
        expect(dialer.dialed, hasLength(1));
      },
    );

    test('a redirect to a name that resolves local is refused', () async {
      tls.handler = (r) => redirect(r, 'https://inner.example.test/x');
      final resolver = FakeResolver({
        'repo.example.test': [
          [fakePublicIp],
        ],
        'inner.example.test': [
          ['192.168.1.9'],
        ],
      });
      final (client, dialer) = publicClient(resolver);
      final e = await failure(
        client.fetchCatalog(
          Uri.parse('https://repo.example.test:${tls.port}/c.json'),
        ),
      );
      expect(e.reason, RepoAddressProblem.localFromPublic);
      expect(dialer.dialed, hasLength(1));
    });

    test('a redirect to plain http on a public name is refused', () async {
      tls.handler = (r) => redirect(r, 'http://cdn.example.test/a.zip');
      final resolver = FakeResolver({
        'repo.example.test': [
          [fakePublicIp],
        ],
      });
      final (client, _) = publicClient(resolver);
      final e = await failure(
        client.fetchCatalog(
          Uri.parse('https://repo.example.test:${tls.port}/c.json'),
        ),
      );
      expect(e.reason, RepoAddressProblem.publicNeedsHttps);
    });

    test('a local catalog may redirect to another local address', () async {
      final other = await TestServer.start();
      addTearDown(other.close);
      other.handler = (r) => respond(r, [5]);
      plain.handler = (r) => redirect(r, 'http://127.0.0.1:${other.port}/y');
      final response = await RepoHttp().fetchCatalog(
        Uri.parse('http://127.0.0.1:${plain.port}/c.json'),
      );
      expect(response.bytes, [5]);
    });

    test('a redirect without Location is a network failure', () async {
      plain.handler = (r) async {
        r.response.statusCode = 302;
        await r.response.close();
      };
      final e = await failure(
        RepoHttp().fetchCatalog(
          Uri.parse('http://127.0.0.1:${plain.port}/c.json'),
        ),
      );
      expect(e.kind, RepoFetchErrorKind.network);
    });
  });

  group('status and caps', () {
    Uri url(String path) => Uri.parse('http://127.0.0.1:${plain.port}$path');

    test('404 and 410 are not found; other errors are network', () async {
      for (final (status, kind) in [
        (404, RepoFetchErrorKind.notFound),
        (410, RepoFetchErrorKind.notFound),
        (500, RepoFetchErrorKind.network),
        (403, RepoFetchErrorKind.network),
      ]) {
        plain.handler = (r) => respond(r, [], status: status);
        final e = await failure(RepoHttp().fetchCatalog(url('/c.json')));
        expect(e.kind, kind, reason: '$status');
      }
    });

    test('a refused connection is a network failure', () async {
      final port = plain.port;
      await plain.close();
      final e = await failure(
        RepoHttp().fetchCatalog(Uri.parse('http://127.0.0.1:$port/c.json')),
      );
      expect(e.kind, RepoFetchErrorKind.network);
      plain = await TestServer.start();
    });

    test('catalog over 1 MiB (declared length)', () async {
      plain.handler = (r) => respond(r, Uint8List(repoCatalogMaxBytes + 1));
      final e = await failure(RepoHttp().fetchCatalog(url('/c.json')));
      expect(e.kind, RepoFetchErrorKind.tooLarge);
    });

    test('catalog of exactly 1 MiB is accepted', () async {
      plain.handler = (r) => respond(r, Uint8List(repoCatalogMaxBytes));
      final response = await RepoHttp().fetchCatalog(url('/c.json'));
      expect(response.bytes, hasLength(repoCatalogMaxBytes));
    });

    test('chunked body over the cap stops being read', () async {
      plain.handler = (r) async {
        r.response.headers.chunkedTransferEncoding = true;
        // Far more than the cap; the client must hang up first.
        for (var i = 0; i < 64; i++) {
          r.response.add(Uint8List(64 * 1024));
          await r.response.flush();
        }
        await r.response.close();
      };
      final e = await failure(RepoHttp().fetchCatalog(url('/c.json')));
      expect(e.kind, RepoFetchErrorKind.tooLarge);
    });

    test('zip over 5 MiB and icon over 64 KiB', () async {
      plain.handler = (r) => respond(r, Uint8List(repoZipMaxBytes + 1));
      final zip = await failure(
        RepoHttp().fetchZip(url('/a.zip'), catalogKind: RepoAddressKind.local),
      );
      expect(zip.kind, RepoFetchErrorKind.tooLarge);

      plain.handler = (r) => respond(r, Uint8List(repoIconMaxBytes + 1));
      final icon = await failure(
        RepoHttp().fetchIcon(url('/i.png'), catalogKind: RepoAddressKind.local),
      );
      expect(icon.kind, RepoFetchErrorKind.tooLarge);
    });

    test('a zip of 4 MiB is accepted', () async {
      plain.handler = (r) => respond(r, Uint8List(4 * 1024 * 1024));
      final response = await RepoHttp().fetchZip(
        url('/a.zip'),
        catalogKind: RepoAddressKind.local,
      );
      expect(response.bytes, hasLength(4 * 1024 * 1024));
    });
  });
}
