import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/plugin_host_patterns.dart';

void main() {
  group('pluginHostPatternProblem', () {
    for (final pattern in [
      'googlevideo.com',
      '*.googlevideo.com',
      '*.a.b.example.com',
      '*.xn--p1ai.example',
    ]) {
      test('accepts $pattern', () {
        expect(pluginHostPatternProblem(pattern), isNull);
      });
    }

    for (final pattern in [
      '*',
      '*.com',
      '*.local',
      '*.1.2.3',
      'a.*.b.com',
      '*foo.com',
      '**.a.com',
      '*.',
      '*.*.a.com',
      'a.com*',
      '*.localhost',
      '*.api.localhost',
      '*.127.0.0.1',
      '*.-a.com',
      '*.Example.com',
      '*.a.com:443',
      '',
    ]) {
      test('refuses "$pattern"', () {
        expect(pluginHostPatternProblem(pattern), isNotNull);
      });
    }
  });

  group('pluginHostListProblem', () {
    test('a plain list passes with or without wildcards allowed', () {
      for (final allowed in [true, false]) {
        expect(
          pluginHostListProblem([
            'www.youtube.com',
            'youtubei.googleapis.com',
          ], wildcardsAllowed: allowed),
          isNull,
        );
      }
    });

    test('wildcards up to the cap pass when allowed', () {
      expect(
        pluginHostListProblem([
          'www.youtube.com',
          for (var i = 0; i < maxPluginHostWildcards; i++) '*.h$i.example.com',
        ], wildcardsAllowed: true),
        isNull,
      );
    });

    test('any wildcard is refused when wildcards are not allowed', () {
      for (final wildcard in ['*.googlevideo.com', '*.ytimg.com']) {
        final found = pluginHostListProblem([
          'www.youtube.com',
          wildcard,
        ], wildcardsAllowed: false);
        expect(found?.entry, wildcard);
        expect(found?.reason, PluginHostRefusal.wildcardNotAllowed);
      }
    });

    test('the first refused entry is reported', () {
      final cases = <List<String>, (String, PluginHostRefusal)>{
        ['www.youtube.com', '*.googlevideo.com']: (
          '*.googlevideo.com',
          PluginHostRefusal.wildcardNotAllowed,
        ),
        ['a.com', '*', '*.b.com']: ('*', PluginHostRefusal.badWildcard),
        ['a.com', 'b..com']: ('b..com', PluginHostRefusal.notPublic),
      };
      for (final MapEntry(key: hosts, value: (entry, reason))
          in cases.entries) {
        final found = pluginHostListProblem(hosts, wildcardsAllowed: false);
        expect(found?.entry, entry, reason: '$hosts');
        expect(found?.reason, reason, reason: '$hosts');
      }
    });

    test('a malformed entry is refused even when wildcards are allowed', () {
      for (final bad in ['*.com', 'a.*.b.com', '*foo.com', '127.0.0.1']) {
        final found = pluginHostListProblem([
          'a.com',
          bad,
        ], wildcardsAllowed: true);
        expect(found?.entry, bad);
        expect(
          found?.reason,
          bad.contains('*')
              ? PluginHostRefusal.badWildcard
              : PluginHostRefusal.notPublic,
        );
      }
    });

    test('a wildcard over a shared-hosting suffix is refused', () {
      for (final base in pluginHostDeniedWildcardBases) {
        final found = pluginHostListProblem([
          '*.$base',
        ], wildcardsAllowed: true);
        expect(found?.entry, '*.$base');
        expect(found?.reason, PluginHostRefusal.sharedHostingWildcard);
      }
      expect(
        pluginHostListProblem(['*.workers.dev'], wildcardsAllowed: true)?.entry,
        '*.workers.dev',
      );
    });

    test('a plain host under a shared-hosting suffix stays allowed', () {
      expect(
        pluginHostListProblem(['someone.github.io'], wildcardsAllowed: false),
        isNull,
      );
    });

    test('the first wildcard over the cap is refused', () {
      final found = pluginHostListProblem([
        for (var i = 0; i < maxPluginHostWildcards; i++) '*.h$i.example.com',
        'plain.com',
        '*.over.example.com',
      ], wildcardsAllowed: true);
      expect(found?.entry, '*.over.example.com');
      expect(found?.reason, PluginHostRefusal.tooManyWildcards);
    });

    test('a repeated wildcard counts once toward the cap', () {
      expect(
        pluginHostListProblem([
          '*.a.com',
          for (var i = 1; i < maxPluginHostWildcards; i++) '*.h$i.example.com',
          '*.a.com',
        ], wildcardsAllowed: true),
        isNull,
      );
    });
  });

  group('PluginHostSet.allows', () {
    final set = PluginHostSet(['*.googlevideo.com', 'www.youtube.com']);

    final table = {
      'rr1---sn-x.googlevideo.com': true,
      'RR1.GoogleVideo.com': true,
      'a.googlevideo.com': true,
      'googlevideo.com': false,
      'a.b.googlevideo.com': false,
      'evilgooglevideo.com': false,
      'googlevideo.com.evil.com': false,
      'rr1.googlevideo.com.': false,
      '-a.googlevideo.com': false,
      'a-.googlevideo.com': false,
      '${'a' * 63}.googlevideo.com': true,
      '${'a' * 64}.googlevideo.com': false,
      '*.googlevideo.com': false,
      'a_b.googlevideo.com': false,
      '.googlevideo.com': false,
      'www.youtube.com': true,
      'WWW.YouTube.com': true,
      'm.youtube.com': false,
      'www.youtube.com.': false,
      '': false,
    };
    for (final MapEntry(key: host, value: allowed) in table.entries) {
      test('${allowed ? 'allows' : 'refuses'} "$host"', () {
        expect(set.allows(host), allowed);
      });
    }

    test('plain entries match exactly, as a set of names', () {
      final plain = PluginHostSet(['lrclib.net', '127.0.0.1']);
      expect(plain.allows('lrclib.net'), isTrue);
      expect(plain.allows('127.0.0.1'), isTrue);
      expect(plain.allows('api.lrclib.net'), isFalse);
      expect(plain.allows('localhost'), isFalse);
    });

    test('an entry that is not a valid pattern matches nothing', () {
      final bad = PluginHostSet([
        '*.com',
        '*.workers.dev',
        'a.*.b.com',
        '*foo.com',
        '*',
      ]);
      for (final host in [
        'x.com',
        'x.workers.dev',
        'a.x.b.com',
        'a.*.b.com',
        'xfoo.com',
        '*foo.com',
        '*',
      ]) {
        expect(bad.allows(host), isFalse, reason: host);
      }
    });
  });
}
