import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/log_redaction.dart';

void main() {
  group('encoded and nested URLs', () {
    test('a Subsonic URL inside a percent-encoded url parameter', () {
      final out = redactSecrets(
        'GET http://127.0.0.1:4040/p?url='
        'https%3A%2F%2Fh%2Frest%2Fstream%3Fu%3Dann%26t%3Dabc%26s%3Dxyz',
      );
      expect(out, isNot(contains('abc')));
      expect(out, isNot(contains('xyz')));
      expect(out, contains('u=ann'));
    });

    test('a percent-encoded parameter name', () {
      final out = redactSecrets('https://h/rest/stream?%74=abc&%73=salt');
      expect(out, isNot(contains('abc')));
      expect(out, isNot(contains('salt')));
    });

    test('text with a broken escape is still checked', () {
      final out = redactSecrets('100% broken %zz https://h/a?token=t0k');
      expect(out, isNot(contains('t0k')));
    });

    test('a nested URL in a plain parameter', () {
      final out = redactSecrets('https://p/x?url=https://h/s?t=abc&id=1');
      expect(out, isNot(contains('abc')));
      expect(out, contains('id=1'));
    });

    test('ordinary percent-encoded paths are left as they are', () {
      const text = 'file:///home/ann/Music/AC%20DC/01%20T.N.T.flac';
      expect(redactSecrets(text), text);
    });
  });

  group('user info', () {
    test('passwords with @, / or # in them', () {
      for (final url in [
        'https://ann:p@ss@dav.example/a',
        'https://ann:pa/ss@dav.example/a',
        'https://ann:pa#ss@dav.example/a',
      ]) {
        expect(redactSecrets(url), 'https://***@dav.example/a', reason: url);
      }
    });

    test('user and password without a scheme', () {
      expect(
        redactSecrets('connect ann:hunter2@dav.example'),
        'connect ***@dav.example',
      );
      expect(redactSecrets('//ann:hunter2@x/a'), '//***@x/a');
    });

    test('user info longer than the usual bound is masked too', () {
      final user = 'u' * 200;
      expect(
        redactSecrets('GET https://$user:pw@host/x'),
        'GET https://***@host/x',
      );
      expect(
        redactSecrets('GET https://$user:p@ss@host/x tail'),
        'GET https://***@host/x tail',
      );
    });

    test('file URLs and e-mail addresses are not user info', () {
      const text = 'file:///home/ann/cover@2x.jpg by ann@example.com';
      expect(redactSecrets(text), text);
    });
  });

  group('cost', () {
    // Doubling the input must not much more than double the time (a rule
    // that rescans from every position would quadruple it). Each size is
    // timed after a warm-up, as the best of several runs, so a busy machine
    // or a cold JIT does not decide the result. The ratio base has a floor:
    // below it, a run is too short to compare.
    //
    // The prefix opens every gate (`@`, `eyJ`, `cookie`, `bearer`,
    // `authorization`, a separator and a secret word) on lines of their own,
    // so the rules really run on the long run that follows. Without it a line
    // that fails the gates passes whatever the rules cost.
    const gatesOpen = 'key=1 @ eyJ\ncookie\nbearer\nauthorization\n';
    final builders = <String, String Function(int)>{
      'key': (n) => '&${'key' * (n ~/ 3)}',
      'dot': (n) => 'a.' * (n ~/ 2),
      'x-': (n) => 'x-${'x-' * (n ~/ 2)}',
      'eyJ': (n) => 'eyJ' * (n ~/ 3),
      'colon': (n) => 'a:' * (n ~/ 2),
      'host': (n) => 'https://${'a' * n}',
      'slash': (n) => '://' * (n ~/ 3),
      'percent': (n) => '%41' * (n ~/ 3),
      'at': (n) => 'a:b@' * (n ~/ 4),
    };
    for (final prefix in ['', gatesOpen]) {
      test('long runs that only look like secret names scale linearly'
          '${prefix.isEmpty ? '' : ' with every gate open'}', () {
        for (final entry in builders.entries) {
          final small = prefix + entry.value(8000);
          final large = prefix + entry.value(16000);
          for (var i = 0; i < 5; i++) {
            redactSecrets(small);
            redactSecrets(large);
          }
          final tSmall = _bestMicros(small);
          final tLarge = _bestMicros(large);
          expect(tLarge, lessThan(1000000), reason: '${entry.key} ceiling');
          expect(
            tLarge / max(tSmall, 1000),
            lessThan(3),
            reason: '${entry.key}: $tSmall us -> $tLarge us',
          );
        }
      });
    }

    test('a record is cut at the cap, with a note', () {
      final out = redactSecrets('a' * (maxRecordChars + 500));
      expect(out, startsWith('a' * maxRecordChars));
      expect(out, endsWith('…[truncated 500 chars]'));
    });

    test('a secret cut by the cap is not left half logged', () {
      final url = redactSecrets('${'a' * 16370}https://u:secretpw');
      expect(url, isNot(contains('sec')));
      expect(url, startsWith('${'a' * 16370}https:***'));
      expect(url, endsWith('…[truncated 4 chars]'));

      final bare = redactSecrets('${'x ' * 8185}ann:hunter2xxxxxx');
      expect(bare, isNot(contains('hunt')));
      expect(bare, contains(' ann:***'));
      expect(bare, endsWith('…[truncated 3 chars]'));
    });

    test('a secret before the cap is still masked', () {
      final out = redactSecrets('?token=t0k ${'a' * 40000}');
      expect(out, startsWith('?token=*** a'));
    });
  });
}

/// Fastest of fifteen runs of `redactSecrets`, in microseconds.
int _bestMicros(String text) {
  var best = 1 << 62;
  for (var i = 0; i < 15; i++) {
    final watch = Stopwatch()..start();
    redactSecrets(text);
    best = min(best, watch.elapsedMicroseconds);
  }
  return best;
}
