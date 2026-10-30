import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/plugins/repo/repo_address_rules.dart';

List<InternetAddress> _ips(List<String> a) => [
  for (final s in a) InternetAddress(s),
];

void main() {
  const publicIp = '93.184.216.34';

  RepoAddressVerdict judge(
    String url,
    List<String> ips, {
    RepoAddressKind? catalogKind,
  }) => judgeRepoAddress(
    Uri.parse(url),
    addresses: _ips(ips),
    catalogKind: catalogKind,
  );

  group('the repository URL the user typed', () {
    test('local destinations may use http or https, any port', () {
      for (final (url, ip) in [
        ('http://192.168.1.5:8765/plugins.json', '192.168.1.5'),
        ('https://192.168.1.5/plugins.json', '192.168.1.5'),
        ('http://localhost:8080/c.json', '127.0.0.1'),
        ('http://127.0.0.1:1/c.json', '127.0.0.1'),
        ('http://[::1]:9/c.json', '::1'),
        ('http://nas.lan/c.json', '10.0.0.7'),
        ('http://nas.local/c.json', '169.254.3.4'),
        ('http://box.home.arpa/c.json', 'fd00::5'),
        ('http://svc.internal/c.json', '100.64.1.1'),
        ('http://pc.localdomain/c.json', '172.16.0.9'),
        ('http://fe80.example/c.json', 'fe80::1'),
      ]) {
        final v = judge(url, [ip]);
        expect(v.isAllowed, isTrue, reason: url);
        expect(v.kind, RepoAddressKind.local, reason: url);
      }
    });

    test('a public destination needs https', () {
      final plain = judge('http://example.com/x.json', [publicIp]);
      expect(plain.problem, RepoAddressProblem.publicNeedsHttps);
      final secure = judge('https://example.com:8443/x.json', [publicIp]);
      expect(secure.isAllowed, isTrue);
      expect(secure.kind, RepoAddressKind.public);
      expect(
        judge('http://8.8.8.8/x.json', ['8.8.8.8']).problem,
        RepoAddressProblem.publicNeedsHttps,
      );
    });

    test('a public name that resolves to a local address counts as local', () {
      final v = judge('http://example.com/x.json', ['127.0.0.1']);
      expect(v.isAllowed, isTrue);
      expect(v.kind, RepoAddressKind.local);
    });

    test('a mixed answer is refused', () {
      expect(
        judge('https://example.com/x.json', [publicIp, '10.0.0.1']).problem,
        RepoAddressProblem.mixedAddresses,
      );
      expect(
        judge('http://example.com/x.json', ['10.0.0.1', publicIp]).problem,
        RepoAddressProblem.mixedAddresses,
      );
    });

    test('refused ranges are never allowed', () {
      for (final ip in ['0.0.0.0', '224.0.0.1', '255.255.255.255', '::']) {
        expect(
          judge('http://example.com/x.json', [ip]).problem,
          RepoAddressProblem.refusedAddress,
          reason: ip,
        );
      }
    });

    test('a local name that resolves to a public address is refused', () {
      expect(
        judge('https://nas.lan/x.json', [publicIp]).problem,
        RepoAddressProblem.localNameOnPublic,
      );
    });

    test('mapped and NAT64 addresses follow the IPv4 they carry', () {
      expect(
        judge('http://a.example/x', ['::ffff:10.0.0.1']).kind,
        RepoAddressKind.local,
      );
      expect(
        judge('http://a.example/x', ['64:ff9b::808:808']).problem,
        RepoAddressProblem.publicNeedsHttps,
      );
    });

    test('schemes, host and user info', () {
      for (final url in [
        'ftp://192.168.1.5/c.json',
        'file:///etc/passwd',
        'c.json',
        'http:///c.json',
        'javascript:alert(1)',
      ]) {
        expect(
          judge(url, ['192.168.1.5']).problem,
          RepoAddressProblem.invalidUrl,
          reason: url,
        );
      }
      expect(
        judge('https://user:pw@example.com/x.json', [publicIp]).problem,
        RepoAddressProblem.userInfo,
      );
      expect(
        judge('https://user@example.com/x.json', [publicIp]).problem,
        RepoAddressProblem.userInfo,
      );
    });
  });

  group('a reference inside a catalog', () {
    test('a public catalog may point to public https only', () {
      const kind = RepoAddressKind.public;
      expect(
        judge('https://cdn.example.com/a.zip', [
          publicIp,
        ], catalogKind: kind).isAllowed,
        isTrue,
      );
      expect(
        judge('http://cdn.example.com/a.zip', [
          publicIp,
        ], catalogKind: kind).problem,
        RepoAddressProblem.publicNeedsHttps,
      );
      for (final (url, ip) in [
        ('http://10.0.0.2/a.zip', '10.0.0.2'),
        ('https://10.0.0.2/a.zip', '10.0.0.2'),
        ('https://localhost/a.zip', '127.0.0.1'),
        ('https://evil.example.com/a.zip', '192.168.0.9'), // rebinding name
        ('https://[::1]/a.zip', '::1'),
        ('https://169.254.169.254/latest', '169.254.169.254'),
      ]) {
        expect(
          judge(url, [ip], catalogKind: kind).problem,
          RepoAddressProblem.localFromPublic,
          reason: url,
        );
      }
    });

    test(
      'a local catalog may point to local addresses and to public https',
      () {
        const kind = RepoAddressKind.local;
        expect(
          judge('http://192.168.1.5:8765/a.zip', [
            '192.168.1.5',
          ], catalogKind: kind).isAllowed,
          isTrue,
        );
        expect(
          judge('https://cdn.example.com/a.zip', [
            publicIp,
          ], catalogKind: kind).isAllowed,
          isTrue,
        );
        expect(
          judge('http://cdn.example.com/a.zip', [
            publicIp,
          ], catalogKind: kind).problem,
          RepoAddressProblem.publicNeedsHttps,
        );
      },
    );

    test('no user info and no refused range, whoever points to it', () {
      for (final kind in RepoAddressKind.values) {
        expect(
          judge('https://u:p@10.0.0.1/a.zip', [
            '10.0.0.1',
          ], catalogKind: kind).problem,
          RepoAddressProblem.userInfo,
        );
        expect(
          judge('https://x.example/a.zip', [
            '0.0.0.0',
          ], catalogKind: kind).problem,
          RepoAddressProblem.refusedAddress,
        );
      }
    });
  });

  group('without a lookup', () {
    RepoAddressVerdict staticJudge(String url, RepoAddressKind? kind) =>
        judgeRepoAddress(Uri.parse(url), catalogKind: kind);

    test('IP literals and local names are decided', () {
      expect(
        staticJudge('http://10.0.0.2/a.zip', RepoAddressKind.public).problem,
        RepoAddressProblem.localFromPublic,
      );
      expect(
        staticJudge('https://nas.lan/a.zip', RepoAddressKind.public).problem,
        RepoAddressProblem.localFromPublic,
      );
      expect(
        staticJudge(
          'http://192.168.1.5/a.zip',
          RepoAddressKind.local,
        ).isAllowed,
        isTrue,
      );
      expect(
        staticJudge('http://8.8.8.8/a.zip', RepoAddressKind.local).problem,
        RepoAddressProblem.publicNeedsHttps,
      );
    });

    test('other names wait for the lookup, except plain http from public', () {
      expect(
        staticJudge(
          'https://cdn.example.com/a.zip',
          RepoAddressKind.public,
        ).isAllowed,
        isTrue,
      );
      expect(
        staticJudge(
          'http://cdn.example.com/a.zip',
          RepoAddressKind.public,
        ).problem,
        RepoAddressProblem.publicNeedsHttps,
      );
      final unknown = staticJudge('http://nas/a.zip', RepoAddressKind.local);
      expect(unknown.isAllowed, isTrue);
      expect(unknown.kind, isNull);
      expect(staticJudge('http://example.com/x', null).isAllowed, isTrue);
    });
  });

  group('checkRepoAddress', () {
    test('resolves a name once and judges the answer', () async {
      var calls = 0;
      final verdict = await checkRepoAddress(
        Uri.parse('http://example.com/x.json'),
        resolver: (host) async {
          calls++;
          return _ips(['10.0.0.8']);
        },
      );
      expect(calls, 1);
      expect(verdict.kind, RepoAddressKind.local);
    });

    test('an IP literal needs no lookup', () async {
      final verdict = await checkRepoAddress(
        Uri.parse('http://192.168.1.5:8765/plugins.json'),
        resolver: (host) => fail('must not resolve'),
      );
      expect(verdict.isAllowed, isTrue);
    });

    test('a bad URL is refused before any lookup', () async {
      final verdict = await checkRepoAddress(
        Uri.parse('ftp://example.com/x'),
        resolver: (host) => fail('must not resolve'),
      );
      expect(verdict.problem, RepoAddressProblem.invalidUrl);
    });

    test('a public name that resolves to loopback is refused for a public '
        'catalog', () async {
      final verdict = await checkRepoAddress(
        Uri.parse('https://example.com/a.zip'),
        catalogKind: RepoAddressKind.public,
        resolver: (host) async => _ips(['127.0.0.1']),
      );
      expect(verdict.problem, RepoAddressProblem.localFromPublic);
    });

    test('an empty answer is a network problem, not a refused address', () {
      expect(
        checkRepoAddress(
          Uri.parse('https://example.com/a.zip'),
          resolver: (host) async => const [],
        ),
        throwsA(isA<SocketException>()),
      );
    });

    test('a lookup that never ends times out as a network problem', () {
      expect(
        checkRepoAddress(
          Uri.parse('https://example.com/a.zip'),
          resolver: (host) => Completer<List<InternetAddress>>().future,
          lookupTimeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<SocketException>()),
      );
    });
  });
}
