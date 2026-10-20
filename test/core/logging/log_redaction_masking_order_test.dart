import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/log_redaction.dart';

/// Masking of long user info and of a record cut at the cap must never leave
/// more of a secret than the rules alone would.
void main() {
  final long = 'a' * 140; // A path past the user info bound of 128.

  group('long user info', () {
    test('does not hide the name of a secret that follows', () {
      final out = redactSecrets(
        'GET https://h/$long?u=bob&p=hunt@ER2SECRET ok',
      );
      expect(out, isNot(contains('ER2SECRET')));
      expect(out, isNot(contains('hunt')));
      expect(out, endsWith(' ok'));
    });

    test('does not hide a header that sits inside the word', () {
      final out = redactSecrets('https://h/$long,authorization=x@SECRETTAIL');
      expect(out, isNot(contains('SECRETTAIL')));
    });

    test('does not hide a secret that is percent-encoded', () {
      final out = redactSecrets(
        'GET https://h/$long?u=bob%26p%3Dhunt%40ER2SECRET ok',
      );
      expect(out, isNot(contains('ER2SECRET')));
      expect(out, isNot(contains('hunt')));
    });

    test('still masks the user info itself', () {
      final out = redactSecrets('GET https://${'u' * 200}:pw@host/x');
      expect(out, 'GET https://***@host/x');
    });
  });

  group('cut at the cap', () {
    String cutAfter(String secret, String rest) =>
        '${'x ' * ((maxRecordChars - secret.length) ~/ 2)}'
        '${'x' * ((maxRecordChars - secret.length) % 2)}$secret$rest';

    test('keeps the masking of the part before the cut', () {
      final text = cutAfter('ann:pa55:w0rd@', 'nas');
      expect(text.indexOf('nas'), maxRecordChars);
      final out = redactSecrets(text);
      expect(out, isNot(contains('pa55')));
      expect(out, isNot(contains('w0rd')));
      expect(out, endsWith('…[truncated 3 chars]'));
    });

    test('masks a secret whose separators are percent-encoded', () {
      final text = cutAfter('ann%3Apa55%3Aw0rd%40', 'nas');
      final out = redactSecrets(text);
      expect(out, isNot(contains('pa55')));
      expect(out, isNot(contains('w0rd')));
    });

    test('masks a half-written value from its separator', () {
      final out = redactSecrets(cutAfter('?u=1&token=abcdef', 'ghi'));
      expect(out, isNot(contains('abcdef')));
    });
  });

  group('decoded copy of long user info', () {
    test('is redacted again after the long user info is masked', () {
      final out = redactSecrets(
        'HTTPS://bob:YQ%22V3XKJ@h/$long?Jwt=Q14266X4%70 ok',
      );
      expect(out, isNot(contains('Q14266X4')));
      expect(out, isNot(contains('YQ')));
    });
  });
}
