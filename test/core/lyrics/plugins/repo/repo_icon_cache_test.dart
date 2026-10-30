import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_catalog.dart';
import 'package:kanaru/core/lyrics/plugins/repo/plugin_repo.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_http.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_icon_cache.dart';

import '../package/package_test_helpers.dart';
import 'repo_test_support.dart';

void main() {
  late TestServer server;
  late RepoIconCache cache;
  late FakeResolver resolver;
  var now = DateTime(2030);
  late PluginRepo repo;

  PluginCatalogEntry entry(String path) => PluginCatalogEntry(
    slug: 's',
    name: 'S',
    version: 1,
    apiVersion: 1,
    hosts: const ['h.example.com'],
    path: Uri.parse('http://repo.lan:8080/s.zip'),
    icon: Uri.parse('http://repo.lan:8080$path'),
  );

  setUp(() async {
    server = await TestServer.start();
    resolver = FakeResolver({
      'repo.lan': [
        ['192.168.1.5'],
      ],
    });
    now = DateTime(2030);
    cache = RepoIconCache(
      RepoHttp(resolver: resolver.call, dialer: RecordingDialer(server).call),
      clock: () => now,
    );
    repo = PluginRepo(
      url: 'http://repo.lan:8080/plugins.json',
      name: 'R',
      author: '',
      addedAt: 1,
      kind: RepoAddressKind.local,
    );
    server.handler = (request) async {
      if (request.uri.path == '/ok.png') {
        request.response.add(pngHeader(64, 64));
      } else if (request.uri.path == '/big.png') {
        request.response.add(pngHeader(1000, 1000));
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    };
  });
  tearDown(() => server.close());

  test('fetches a good icon once and serves it from memory', () async {
    final a = await cache.iconOf(repo, entry('/ok.png'));
    final b = await cache.iconOf(repo, entry('/ok.png'));
    expect(a, isA<Uint8List>());
    expect(b, a);
    expect(server.requests, hasLength(1));
  });

  test('concurrent asks share one fetch', () async {
    final results = await Future.wait([
      for (var i = 0; i < 5; i++) cache.iconOf(repo, entry('/ok.png')),
    ]);
    expect(results.every((r) => r != null), isTrue);
    expect(server.requests, hasLength(1));
  });

  test('a bad or missing icon is null and not asked again', () async {
    expect(await cache.iconOf(repo, entry('/big.png')), isNull);
    expect(await cache.iconOf(repo, entry('/none.png')), isNull);
    await cache.iconOf(repo, entry('/big.png'));
    expect(server.requests, hasLength(2));
  });

  test(
    'no icon address or unknown repo kind gives null without a request',
    () async {
      final noIcon = PluginCatalogEntry(
        slug: 's',
        name: 'S',
        version: 1,
        apiVersion: 1,
        hosts: const ['h.example.com'],
        path: Uri.parse('http://repo.lan/s.zip'),
      );
      expect(await cache.iconOf(repo, noIcon), isNull);
      final never = PluginRepo(
        url: repo.url,
        name: 'R',
        author: '',
        addedAt: 1,
      );
      expect(await cache.iconOf(never, entry('/ok.png')), isNull);
      expect(server.requests, isEmpty);
    },
  );

  group('the address class of the repository', () {
    test(
      'a name that now resolves public gets no icon and no request',
      () async {
        resolver.answers['repo.lan'] = [
          ['93.184.216.34'],
        ];
        expect(await cache.iconOf(repo, entry('/ok.png')), isNull);
        expect(server.requests, isEmpty);
      },
    );

    test('is looked up once for a list of icons', () async {
      await Future.wait([
        for (var i = 0; i < 20; i++) cache.iconOf(repo, entry('/ok$i.png')),
      ]);
      expect(
        resolver.lookups.where((h) => h == 'repo.lan').length,
        lessThanOrEqualTo(21),
      );
      // One lookup for the class; the others are the pinned connections.
      final classLookups = resolver.lookups.length - server.requests.length;
      expect(classLookups, 1);
    });
  });

  group('failures', () {
    test('a network failure is retried later, not cached for good', () async {
      resolver.answers.remove('repo.lan');
      expect(await cache.iconOf(repo, entry('/ok.png')), isNull);
      // Still inside the retry window: no new attempt.
      resolver.answers['repo.lan'] = [
        ['192.168.1.5'],
      ];
      expect(await cache.iconOf(repo, entry('/ok.png')), isNull);
      expect(server.requests, isEmpty);

      now = now.add(repoIconRetryAfter + const Duration(seconds: 1));
      expect(await cache.iconOf(repo, entry('/ok.png')), isA<Uint8List>());
    });

    test('clearFailures lets the next ask try at once', () async {
      resolver.answers.remove('repo.lan');
      expect(await cache.iconOf(repo, entry('/ok.png')), isNull);
      resolver.answers['repo.lan'] = [
        ['192.168.1.5'],
      ];
      cache.clearFailures();
      expect(await cache.iconOf(repo, entry('/ok.png')), isA<Uint8List>());
    });
  });

  group('a refused recheck of the repository address', () {
    void refuse() => resolver.answers['repo.lan'] = [
      ['0.0.0.0'],
    ];
    void allow() => resolver.answers['repo.lan'] = [
      ['192.168.1.5'],
    ];

    test('is retried after the window, not remembered as missing', () async {
      refuse();
      expect(await cache.iconOf(repo, entry('/ok.png')), isNull);
      expect(server.requests, isEmpty);
      allow();
      // Inside the window: no new attempt.
      expect(await cache.iconOf(repo, entry('/ok.png')), isNull);
      expect(server.requests, isEmpty);
      now = now.add(repoIconRetryAfter + const Duration(seconds: 1));
      expect(await cache.iconOf(repo, entry('/ok.png')), isA<Uint8List>());
    });

    test('clearFailures forgets it', () async {
      refuse();
      expect(await cache.iconOf(repo, entry('/ok.png')), isNull);
      allow();
      cache.clearFailures();
      expect(await cache.iconOf(repo, entry('/ok.png')), isA<Uint8List>());
    });
  });

  test('keeps at most the budget, dropping the least recently used', () async {
    final small = RepoIconCache(
      RepoHttp(resolver: resolver.call, dialer: RecordingDialer(server).call),
      maxBytes: pngHeader(64, 64).length * 2,
    );
    await small.iconOf(repo, entry('/ok.png'));
    await small.iconOf(repo, entry('/ok.png?b'));
    await small.iconOf(repo, entry('/ok.png')); // use the first again
    await small.iconOf(repo, entry('/ok.png?c')); // evicts '?b'
    expect(server.requests, hasLength(3));
    await small.iconOf(repo, entry('/ok.png'));
    expect(server.requests, hasLength(3), reason: 'first one stayed');
    await small.iconOf(repo, entry('/ok.png?b'));
    expect(server.requests, hasLength(4), reason: 'second one was dropped');
  });
}
