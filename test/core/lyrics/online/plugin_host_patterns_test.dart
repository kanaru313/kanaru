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

    test('up to three wildcards pass when allowed', () {
      expect(
        pluginHostListProblem([
          'www.youtube.com',
          '*.googlevideo.com',
          '*.ytimg.com',
          '*.ggpht.com',
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
        expect(found?.problem, isNotEmpty);
      }
    });

    test('the first refused entry is reported', () {
      final cases = <List<String>, String>{
        ['www.youtube.com', '*.googlevideo.com']: '*.googlevideo.com',
        ['a.com', '*', '*.b.com']: '*',
        ['a.com', 'b..com']: 'b..com',
      };
      for (final MapEntry(key: hosts, value: entry) in cases.entries) {
        final found = pluginHostListProblem(hosts, wildcardsAllowed: false);
        expect(found?.entry, entry, reason: '$hosts');
        expect(found?.problem, isNotEmpty);
      }
    });

    test('a malformed entry is refused even when wildcards are allowed', () {
      for (final bad in ['*.com', 'a.*.b.com', '*foo.com', '127.0.0.1']) {
        expect(
          pluginHostListProblem(['a.com', bad], wildcardsAllowed: true)?.entry,
          bad,
        );
      }
    });

    test('a wildcard over a shared-hosting suffix is refused', () {
      for (final base in pluginHostDeniedWildcardBases) {
        final found = pluginHostListProblem([
          '*.$base',
        ], wildcardsAllowed: true);
        expect(found?.entry, '*.$base');
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

    test('a fourth wildcard is refused', () {
      final found = pluginHostListProblem([
        '*.a.com',
        '*.b.com',
        'plain.com',
        '*.c.com',
        '*.d.com',
      ], wildcardsAllowed: true);
      expect(found?.entry, '*.d.com');
      expect(found?.problem, isNotEmpty);
    });

    test('a repeated wildcard counts once toward the cap', () {
      expect(
        pluginHostListProblem([
          '*.a.com',
          '*.a.com',
          '*.b.com',
          '*.c.com',
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
