import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_package_reader.dart';
import 'package:kanaru/core/lyrics/plugins/repo/lyrics_plugin_repos_controller.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_fetch_exception.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_http.dart';

import '../store/store_test_env.dart';
import 'repo_controller_env.dart';
import 'repo_test_support.dart';

const publicIp = fakePublicIp;
const localIp = '192.168.1.5';

Future<void> expectBlocked(
  Future<Object?> call,
  RepoAddressProblem reason,
) async {
  await expectLater(
    call,
    throwsA(
      isA<RepoFetchException>()
          .having((e) => e.kind, 'kind', RepoFetchErrorKind.blockedAddress)
          .having((e) => e.reason, 'reason', reason),
    ),
  );
}

void main() {
  group('the class used at install and update time', () {
    late RepoEnv env;

    setUp(() async {
      env = await RepoEnv.create();
      env.serveCatalog([entryJson()]);
      env.routes['/demo.zip'] = pluginZip();
      await env.repos.add(catalogUrl);
    });
    tearDown(() => env.dispose());

    int zipRequests() =>
        env.server.requests.where((r) => r.uri.path == '/demo.zip').length;

    RepoPluginFailed failed(RepoPluginResult r) => r as RepoPluginFailed;

    test(
      'a repo name that now resolves public is refused, no request',
      () async {
        env.resolver.answers['repo.lan'] = [
          [publicIp],
        ];
        final result = failed(await env.repos.install(catalogUrl, 'demo'));
        expect(result.failure, RepoPluginFailure.download);
        expect(result.fetchError!.kind, RepoFetchErrorKind.blockedAddress);
        expect(result.fetchError!.reason, RepoAddressProblem.localNameOnPublic);
        expect(zipRequests(), 0);
        expect(await env.store.controller.watchRecords().first, isEmpty);
      },
    );

    test(
      'a lookup that fails is a network error, never the stored class',
      () async {
        env.resolver.answers.remove('repo.lan');
        final result = failed(await env.repos.install(catalogUrl, 'demo'));
        expect(result.failure, RepoPluginFailure.download);
        expect(result.fetchError!.kind, RepoFetchErrorKind.network);
        expect(zipRequests(), 0);
      },
    );

    test('an update is checked the same way', () async {
      final id = ((await env.repos.install(
        catalogUrl,
        'demo',
      )) as RepoPluginDone).record.installId;
      env.serveCatalog([entryJson(version: 4)]);
      env.routes['/demo.zip'] = pluginZip(version: 4);
      await env.repos.refreshAll();
      final before = zipRequests();
      env.resolver.answers['repo.lan'] = [
        [publicIp],
      ];
      final result = failed(await env.repos.update(id));
      expect(result.fetchError!.reason, RepoAddressProblem.localNameOnPublic);
      expect(zipRequests(), before);
      expect(
        (await env.store.controller.watchRecords().first).single.version,
        3,
      );
    });

    test('a repo that stays local still installs', () async {
      expect(
        await env.repos.install(catalogUrl, 'demo'),
        isA<RepoPluginDone>(),
      );
    });
  });

  group('RepoHttp.effectiveKind', () {
    RepoHttp http(Map<String, List<List<String>>> answers) =>
        RepoHttp(resolver: FakeResolver(answers).call);

    final url = Uri.parse('https://repo.example/plugins.json');

    test('is the stricter of the stored class and the fresh one', () async {
      final local = http({
        'repo.example': [
          [localIp],
        ],
      });
      final public = http({
        'repo.example': [
          [publicIp],
        ],
      });
      expect(
        await local.effectiveKind(url, RepoAddressKind.local),
        RepoAddressKind.local,
      );
      // Stored local, now public: the stricter wins.
      expect(
        await public.effectiveKind(url, RepoAddressKind.local),
        RepoAddressKind.public,
      );
      // Stored public (it narrowed along a redirect), fresh sees only the
      // first hop and says local: never the fresh class alone.
      expect(
        await local.effectiveKind(url, RepoAddressKind.public),
        RepoAddressKind.public,
      );
    });

    test('fails closed', () async {
      await expectLater(
        http({}).effectiveKind(url, RepoAddressKind.local),
        throwsA(
          isA<RepoFetchException>().having(
            (e) => e.kind,
            'kind',
            RepoFetchErrorKind.network,
          ),
        ),
      );
      await expectBlocked(
        http({
          'repo.example': [
            [publicIp],
          ],
        }).effectiveKind(
          Uri.parse('http://repo.example/plugins.json'),
          RepoAddressKind.local,
        ),
        RepoAddressProblem.publicNeedsHttps,
      );
      await expectBlocked(
        http({
          'repo.example': [
            [localIp, publicIp],
          ],
        }).effectiveKind(url, RepoAddressKind.local),
        RepoAddressProblem.mixedAddresses,
      );
    });
  });

  group('zip redirects narrow to public', () {
    late TestServer tls;
    late FakeResolver resolver;
    late RepoHttp http;
    final base = 'repo.example.test';

    setUp(() async {
      tls = await TestServer.start(secure: true);
      resolver = FakeResolver({
        base: [
          [publicIp],
        ],
      });
      http = RepoHttp(
        resolver: resolver.call,
        dialer: RecordingDialer(tls).call,
        securityContext: trustingTestCert(),
      );
    });
    tearDown(() => tls.close());

    test(
      'a local catalog\'s zip on a public host cannot reach local',
      () async {
        tls.handler = (r) async {
          r.response
            ..statusCode = 302
            ..headers.set('location', 'http://10.0.0.9/x.zip');
          await r.response.close();
        };
        await expectBlocked(
          http.fetchZip(
            Uri.parse('https://$base:${tls.port}/a.zip'),
            catalogKind: RepoAddressKind.local,
          ),
          RepoAddressProblem.localFromPublic,
        );
      },
    );

    test('and so cannot an icon', () async {
      tls.handler = (r) async {
        r.response
          ..statusCode = 302
          ..headers.set('location', 'http://10.0.0.9/x.png');
        await r.response.close();
      };
      await expectBlocked(
        http.fetchIcon(
          Uri.parse('https://$base:${tls.port}/a.png'),
          catalogKind: RepoAddressKind.local,
        ),
        RepoAddressProblem.localFromPublic,
      );
    });
  });

  group('a public repository end to end', () {
    late StoreEnv store;
    late TestServer tls;
    late LyricsPluginReposController repos;
    late String url;

    setUp(() async {
      store = await StoreEnv.create();
      tls = await TestServer.start(secure: true);
      final resolver = FakeResolver({
        'repo.example.test': [
          [publicIp],
        ],
      });
      repos = LyricsPluginReposController(
        db: store.db,
        plugins: store.controller,
        reader: PluginPackageReader(FakeRuntime()),
        http: RepoHttp(
          resolver: resolver.call,
          dialer: RecordingDialer(tls).call,
          securityContext: trustingTestCert(),
        ),
      );
      url = 'https://repo.example.test:${tls.port}/plugins.json';
      final zip = pluginZip();
      tls.handler = (r) async {
        switch (r.uri.path) {
          case '/plugins.json':
            r.response.add(
              utf8.encode(
                catalogJson([
                  entryJson(path: 'a.zip'),
                  entryJson(slug: 'hop', name: 'Hop', path: 'hop.zip'),
                ]),
              ),
            );
          case '/a.zip':
            r.response.add(zip);
          case '/hop.zip':
            r.response
              ..statusCode = 302
              ..headers.set('location', 'http://192.168.1.1/a.zip');
          default:
            r.response.statusCode = 404;
        }
        await r.response.close();
      };
    });
    tearDown(() async {
      await tls.close();
      await store.dispose();
    });

    test(
      'the stored class public applies to the zip and its redirects',
      () async {
        expect(await repos.add(url), isA<AddRepoAdded>());
        final stored = (await repos.watchRepos().first).single;
        expect(stored.kind, RepoAddressKind.public);

        final hop = await repos.install(url, 'hop') as RepoPluginFailed;
        expect(hop.fetchError!.kind, RepoFetchErrorKind.blockedAddress);
        expect(hop.fetchError!.reason, RepoAddressProblem.localFromPublic);

        expect(await repos.install(url, 'demo'), isA<RepoPluginDone>());
      },
    );
  });
}
