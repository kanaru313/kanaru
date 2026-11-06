import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';

import 'support/http_test_lyrics_provider.dart';

class _Stub implements LyricsProvider {
  _Stub(this.id, this.hosts);

  @override
  final String id;

  @override
  List<String> hosts;

  @override
  String get displayName => 'Stub $id';

  @override
  Future<LyricsCandidate?> lookup(LyricsQuery query, LyricsHttp http) async =>
      null;

  @override
  Future<List<LyricsCandidate>> search(LyricsQuery q, LyricsHttp http) async =>
      const [];

  @override
  Future<LyricsBody?> fetch(String remoteId, LyricsHttp http) async => null;
}

void main() {
  test('a registry holds the HTTP test provider', () {
    final registration = registerLyricsProviders([HttpTestLyricsProvider()])
        .single;
    expect(registration.id, 'test-http');
    expect(registration.hosts, ['lyrics.test.net']);
  });

  test('a duplicate id is rejected', () {
    expect(
      () => registerLyricsProviders([
        _Stub('a', ['a.example.com']),
        _Stub('a', ['b.example.com']),
      ]),
      throwsArgumentError,
    );
  });

  for (final host in [
    '127.0.0.1',
    'localhost',
    'api.localhost',
    '10.0.0.1',
    '169.254.1.1',
    '127.0.0.0x1',
    '0x7f.0x1',
    '127.1.0x0',
    '1.2.3.4a',
    'example.1com',
    '[::1]',
    'music',
    'lyrics.test.net:8443',
    'lyrics.test.net/path',
    'user@lyrics.test.net',
    'printer.local',
    'nas.home.arpa',
    'box.localdomain',
    '',
    'a..b.com',
    '-a.example.com',
    'https://lyrics.test.net',
  ]) {
    test('host "$host" is rejected', () {
      expect(
        () => LyricsProviderRegistration(_Stub('x', [host])),
        throwsArgumentError,
      );
    });
  }

  test('internationalized and ordinary public hosts are accepted', () {
    expect(lyricsHostProblem('xn--80ak6aa92e.com'), isNull);
    expect(lyricsHostProblem('music.xn--p1ai'), isNull);
    expect(lyricsHostProblem('a1.example.co.uk'), isNull);
  });

  test('no host, or a malformed id, is rejected', () {
    expect(
      () => LyricsProviderRegistration(_Stub('x', [])),
      throwsArgumentError,
    );
    expect(
      () => LyricsProviderRegistration(_Stub('a@b', ['a.example.com'])),
      throwsArgumentError,
    );
  });

  test('a repeated host is kept once', () {
    final r = LyricsProviderRegistration(
      _Stub('x', ['b.example.com', 'A.example.com', 'a.example.com']),
    );
    expect(r.hosts, ['a.example.com', 'b.example.com']);
  });

  test('hosts are lower-cased and the snapshot cannot change', () {
    final stub = _Stub('x', ['API.Example.com']);
    final r = LyricsProviderRegistration(stub);
    stub.hosts = ['evil.example.com'];
    expect(r.hosts, ['api.example.com']);
    expect(() => r.hosts.add('a.b.com'), throwsUnsupportedError);
  });
}
