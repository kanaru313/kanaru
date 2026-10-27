import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/log_format.dart';
import 'package:kanaru/core/logging/log_redaction.dart';
import 'package:logging/logging.dart';

void main() {
  test('masks Subsonic password, token and salt but keeps other params', () {
    expect(
      redactSecrets(
        'GET https://music.example/rest/stream?u=ann&t=abc&s=xyz&id=7',
      ),
      'GET https://music.example/rest/stream?u=ann&t=***&s=***&id=7',
    );
  });

  test('masks a DeepL auth key, with or without the header name', () {
    const key = '00000000-0000-0000-0000-000000000000:fx';
    expect(
      redactSecrets('Authorization: DeepL-Auth-Key $key'),
      'Authorization: ***',
    );
    final bare = redactSecrets('headers {a: DeepL-Auth-Key $key, b: 1}\nnext');
    expect(bare, 'headers {a: DeepL-Auth-Key ***\nnext');
    expect(redactSecrets('deepl-auth-key $key'), 'deepl-auth-key ***');
  });

  test('a DeepL key word in prose masks the rest of the line', () {
    expect(
      redactSecrets('bad deepl-auth-key format, see settings\nnext'),
      'bad deepl-auth-key ***\nnext',
    );
  });

  test('masks S3 presigned parameters', () {
    final out = redactSecrets(
      'https://b.s3.example/k.flac?X-Amz-Credential=AKIA%2F1&'
      'X-Amz-Signature=deadbeef&versionId=3',
    );
    expect(out, isNot(contains('AKIA')));
    expect(out, isNot(contains('deadbeef')));
    expect(out, contains('X-Amz-Signature=***'));
    expect(out, contains('versionId=3'));
  });

  test('masks user info in URLs', () {
    expect(
      redactSecrets('open dav://ann:hunter2@cloud.example/Music/a.flac'),
      'open dav://***@cloud.example/Music/a.flac',
    );
  });

  test('masks Authorization, Cookie and media server token headers', () {
    expect(
      redactSecrets('Authorization: Basic YW5uOmh1bnRlcjI='),
      'Authorization: Basic ***',
    );
    expect(
      redactSecrets('authorization: bearer eyJhbGci.x.y, next'),
      'authorization: bearer ***',
    );
    expect(
      redactSecrets(
        'Authorization: MediaBrowser Client="Kanaru", Token="sekret"\nnext',
      ),
      'Authorization: ***\nnext',
    );
    expect(
      redactSecrets('Authorization: Digest username="ann", response="r1"'),
      'Authorization: Digest ***',
    );
    expect(redactSecrets('Cookie: sid=1; theme=dark'), 'Cookie: ***');
    expect(redactSecrets('X-Plex-Token: abc123'), 'X-Plex-Token: ***');
    expect(redactSecrets('x-emby-token=abc123'), 'x-emby-token=***');
  });

  test('masks secrets in URL fragments, in any case', () {
    expect(
      redactSecrets('https://a.example/cb#access_token=tok&state=1'),
      'https://a.example/cb#access_token=***&state=1',
    );
    expect(redactSecrets('?API_KEY=k1&Session=s1'), '?API_KEY=***&Session=***');
  });

  test('masks a credential that only appears in the error or stack', () {
    final line = formatRecord(
      LogRecord(
        Level.SEVERE,
        'Request failed',
        'storage',
        Exception('GET https://bob:pw@dav.example/a?token=t0k failed'),
        StackTrace.fromString('#0 fetch (https://x.example/?sig=s1g)'),
      ),
    );
    final out = redactSecrets(line);
    expect(out, isNot(contains('pw@')));
    expect(out, isNot(contains('t0k')));
    expect(out, isNot(contains('s1g')));
  });

  test('leaves ordinary text alone', () {
    const text =
        'Playback failed: file:///home/ann/Music/AC-DC/01 T.N.T.flac: '
        'Failed to recognize file format.';
    expect(redactSecrets(text), text);
  });

  group('structured and unprefixed secrets', () {
    test('JSON, Dart maps and logfmt', () {
      expect(
        redactSecrets('{"password":"hunter2","token": "t0k","user":"ann"}'),
        '{"password":"***","token": "***","user":"ann"}',
      );
      final map = redactSecrets('{password: hunter2, apiKey: k3y, user: ann}');
      expect(map, isNot(contains('hunter2')));
      expect(map, isNot(contains('k3y')));
      expect(map, contains('user: ann'));
      expect(
        redactSecrets('password=hunter2&user=ann'),
        'password=***&user=ann',
      );
      expect(redactSecrets('login token=abc123 ok'), 'login token=*** ok');
    });

    test('more secret names, headers and bare tokens', () {
      for (final secret in [
        '?jwt=S1&pwd=S2&pw=S3&credential=S4&ticket=S5&otp=S6',
        'PHPSESSID=S1 JSESSIONID=S2',
        'X-Api-Key: S1',
        'X-MediaBrowser-Token: S1',
        'Cookies: sid=S1',
        '[sessionid=S1; Path=/; HttpOnly]',
        'sent Bearer S1 to the server',
        'got eyJhbGciOi.eyJzdWIi.c2lnbmF0dXJl back',
      ]) {
        expect(redactSecrets(secret), isNot(contains('S1')), reason: secret);
      }
      expect(
        redactSecrets('?jwt=S1&pwd=S2&pw=S3&ticket=S5&otp=S6'),
        isNot(contains('S')),
      );
      expect(
        redactSecrets('got eyJhbGciOi.eyJzdWIi.c2lnbmF0dXJl back'),
        'got *** back',
      );
    });

    test('plain words with the same letters stay readable', () {
      const text = 'status code: 404, signal: SIGTERM, user: ann, id=7';
      expect(redactSecrets(text), text);
    });
  });
}
