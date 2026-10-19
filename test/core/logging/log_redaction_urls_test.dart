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

    test('file URLs and e-mail addresses are not user info', () {
      const text = 'file:///home/ann/cover@2x.jpg by ann@example.com';
      expect(redactSecrets(text), text);
    });
  });

  group('cost', () {
    test('long runs that only look like secret names stay fast', () {
      for (final text in [
        '&${'key' * 16000}',
        'a.' * 16000,
        'x-${'x-' * 16000}',
        'eyJ' * 16000,
        'a:' * 16000,
        'https://${'a' * 48000}',
        '://' * 16000,
        '%41' * 16000,
      ]) {
        final watch = Stopwatch()..start();
        redactSecrets(text);
        expect(
          watch.elapsedMilliseconds,
          lessThan(100),
          reason: text.substring(0, 12),
        );
      }
    });

    test('a record is cut at the cap, with a note', () {
      final out = redactSecrets('a' * (maxRecordChars + 500));
      expect(out, startsWith('a' * maxRecordChars));
      expect(out, endsWith('…[truncated 500 chars]'));
    });

    test('a secret before the cap is still masked', () {
      final out = redactSecrets('?token=t0k ${'a' * 40000}');
      expect(out, startsWith('?token=*** a'));
    });
  });
}
