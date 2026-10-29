import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lrclib_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_http.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider.dart';
import 'package:kanaru/core/lyrics/online/lyrics_provider_registry.dart';

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
  test('the default registry holds LRCLIB with its consent keys', () {
    final registration = registerLyricsProviders([LrclibProvider()]).single;
    expect(registration.id, 'lrclib');
    expect(registration.hosts, ['lrclib.net']);
    expect(registration.consentKey, 'lrclib@lrclib.net');
    expect(registration.autoConsentKey, 'lrclib@lrclib.net:auto');
  });

  test('the consent key lists the hosts sorted', () {
    final r = LyricsProviderRegistration(
      _Stub('x', ['b.example.com', 'a.example.com']),
    );
    expect(r.consentKey, 'x@a.example.com,b.example.com');
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
    '[::1]',
    'music',
    'lrclib.net:8443',
    'lrclib.net/path',
    'user@lrclib.net',
    'printer.local',
    'nas.home.arpa',
    'box.localdomain',
    '',
    'a..b.com',
    '-a.example.com',
    'https://lrclib.net',
  ]) {
    test('host "$host" is rejected', () {
      expect(
        () => LyricsProviderRegistration(_Stub('x', [host])),
        throwsArgumentError,
      );
    });
  }

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

  test('a repeated host is kept once, so the consent key is stable', () {
    final r = LyricsProviderRegistration(
      _Stub('x', ['b.example.com', 'A.example.com', 'a.example.com']),
    );
    expect(r.hosts, ['a.example.com', 'b.example.com']);
    expect(r.consentKey, 'x@a.example.com,b.example.com');
  });

  test('hosts are lower-cased and the snapshot cannot change', () {
    final stub = _Stub('x', ['API.Example.com']);
    final r = LyricsProviderRegistration(stub);
    stub.hosts = ['evil.example.com'];
    expect(r.hosts, ['api.example.com']);
    expect(r.consentKey, 'x@api.example.com');
    expect(() => r.hosts.add('a.b.com'), throwsUnsupportedError);
  });
}
