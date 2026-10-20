import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/log_redaction.dart';

/// Pins what `redactSecrets` returns, input for input. Redaction is a
/// security control: a change may only make it stricter, so any difference
/// here is reviewed by hand. The percent-encoded inputs cover the rules that
/// only fire on the decoded copy of a record.
void main() {
  test('short inputs keep their exact output', () {
    for (final entry in _short.entries) {
      expect(redactSecrets(entry.key), entry.value, reason: entry.key);
    }
  });

  test('hostile inputs keep their exact output', () {
    for (final entry in _hostile().entries) {
      final out = redactSecrets(entry.value.$1);
      expect(out.length, entry.value.$2, reason: '${entry.key} length');
      expect(_fingerprint(out), entry.value.$3, reason: '${entry.key} hash');
    }
  });
}

int _fingerprint(String s) {
  var h = 0x811c9dc5;
  for (final u in s.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0xffffffff;
  }
  return h;
}

const _short = <String, String>{
  'GET https://music.example/rest/stream?u=ann&t=abc&s=xyz&id=7':
      'GET https://music.example/rest/stream?u=ann&t=***&s=***&id=7',
  'https://b.s3.example/k.flac?X-Amz-Credential=AKIA%2F1&X-Amz-Signature=deadbeef&versionId=3': 'https://b.s3.example/k.flac?X-Amz-Credential=***&X-Amz-Signature=***&versionId=3',
  'open dav://ann:hunter2@cloud.example/Music/a.flac':
      'open dav://***@cloud.example/Music/a.flac',
  'Authorization: Basic YW5uOmh1bnRlcjI=': 'Authorization: Basic ***',
  'authorization: bearer eyJhbGci.x.y, next': 'authorization: bearer ***',
  'Authorization: MediaBrowser Client="Kanaru", Token="sekret"\nnext':
      'Authorization: ***\nnext',
  'Authorization: Digest username="ann", response="r1"':
      'Authorization: Digest ***',
  'Cookie: sid=1; theme=dark': 'Cookie: ***',
  'X-Plex-Token: abc123': 'X-Plex-Token: ***',
  'x-emby-token=abc123': 'x-emby-token=***',
  'https://a.example/cb#access_token=tok&state=1':
      'https://a.example/cb#access_token=***&state=1',
  '?API_KEY=k1&Session=s1': '?API_KEY=***&Session=***',
  'Request failed GET https://bob:pw@dav.example/a?token=t0k failed\n#0 fetch (https://x.example/?sig=s1g)': 'Request failed GET https://***@dav.example/a?token=*** failed\n#0 fetch (https://x.example/?sig=***',
  'Playback failed: file:///home/ann/Music/AC-DC/01 T.N.T.flac: Failed to recognize file format.': 'Playback failed: file:///home/ann/Music/AC-DC/01 T.N.T.flac: Failed to recognize file format.',
  '{"password":"hunter2","token": "t0k","user":"ann"}':
      '{"password":"***","token": "***","user":"ann"}',
  '{password: hunter2, apiKey: k3y, user: ann}':
      '{password: ***, apiKey: ***, user: ann}',
  'password=hunter2&user=ann': 'password=***&user=ann',
  'login token=abc123 ok': 'login token=*** ok',
  '?jwt=S1&pwd=S2&pw=S3&credential=S4&ticket=S5&otp=S6':
      '?jwt=***&pwd=***&pw=***&credential=***&ticket=***&otp=***',
  'PHPSESSID=S1 JSESSIONID=S2': 'PHPSESSID=*** JSESSIONID=***',
  'X-Api-Key: S1': 'X-Api-Key: ***',
  'X-MediaBrowser-Token: S1': 'X-MediaBrowser-Token: ***',
  'Cookies: sid=S1': 'Cookies: ***',
  '[sessionid=S1; Path=/; HttpOnly]': '[sessionid=***; Path=/; HttpOnly]',
  'sent Bearer S1 to the server': 'sent Bearer *** to the server',
  'got eyJhbGciOi.eyJzdWIi.c2lnbmF0dXJl back': 'got *** back',
  'status code: 404, signal: SIGTERM, user: ann, id=7':
      'status code: 404, signal: SIGTERM, user: ann, id=7',
  'GET http://127.0.0.1:4040/p?url=https%3A%2F%2Fh%2Frest%2Fstream%3Fu%3Dann%26t%3Dabc%26s%3Dxyz':
      'GET http://127.0.0.1:4040/p?url=https://h/rest/stream?u=ann&t=***&s=***',
  'https://h/rest/stream?%74=abc&%73=salt': 'https://h/rest/stream?t=***&s=***',
  '100% broken %zz https://h/a?token=t0k':
      '100% broken %zz https://h/a?token=***',
  'https://p/x?url=https://h/s?t=abc&id=1':
      'https://p/x?url=https://h/s?t=***&id=1',
  'file:///home/ann/Music/AC%20DC/01%20T.N.T.flac':
      'file:///home/ann/Music/AC%20DC/01%20T.N.T.flac',
  'https://ann:p@ss@dav.example/a': 'https://***@dav.example/a',
  'https://ann:pa/ss@dav.example/a': 'https://***@dav.example/a',
  'https://ann:pa#ss@dav.example/a': 'https://***@dav.example/a',
  'connect ann:hunter2@dav.example': 'connect ***@dav.example',
  '//ann:hunter2@x/a': '//***@x/a',
  'file:///home/ann/cover@2x.jpg by ann@example.com':
      'file:///home/ann/cover@2x.jpg by ann@example.com',
  '?token=t0k aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa':
      '?token=*** aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  '://': '://',
  '://@': '://***@',
  '://:@': '://***@',
  'a://@b://@c': 'a://***@c',
  'http://ann@': 'http://***@',
  'http://@': 'http://***@',
  'user:@host': 'user:@host',
  ':pass@host': ':pass@host',
  'a:b@c:d@e': '***@***@e',
  'bearer': 'bearer',
  'bearer ': 'bearer ',
  'Bearer\tx': 'Bearer\t***',
  'authorization': 'authorization',
  'authorization:': 'authorization:',
  'authorization:\n': 'authorization:\n',
  'Authorization : Bearer tok': 'Authorization : Bearer ***',
  'proxy-authorization=Basic xyz': 'proxy-authorization=Basic ***',
  'cookie': 'cookie',
  'cookie=': 'cookie=',
  'Set-Cookie: a=b; HttpOnly': 'Set-Cookie: ***',
  'eyJ': 'eyJ',
  'eyJabcde.f.g': '***',
  'eyJabcd.f.g': 'eyJabcd.f.g',
  'x-token: v': 'x-token: ***',
  'x-amz-signature=1': 'x-amz-signature=***',
  '?x-amz-signature=1': '?x-amz-signature=***',
  'secret=': 'secret=***',
  'secret: "quoted value" tail': 'secret: "***" tail',
  'token: \'single\' tail': 'token: \'***\' tail',
  '"password":': '"password":***',
  'key=1': 'key=***',
  '?key=1&auth=2&code=3&sig=4': '?key=***&auth=***&code=***&sig=***',
  'a&b=c;token=d#pass=e': 'a&b=c;token=***#pass=***',
  'api-key: k': 'api-key: ***',
  'ACCESS_KEY=1 Private_Key=2': 'ACCESS_KEY=*** Private_Key=***',
  'sid=1 ticket=2 otp=3 pass=4 auth=5':
      'sid=*** ticket=*** otp=*** pass=*** auth=***',
  'TOKEN=UPPER': 'TOKEN=***',
  '\u{fc}n\u{ef}code token=s\u{e9}cret \u{2713}':
      '\u{fc}n\u{ef}code token=*** \u{2713}',
  '\u{1f600} password=\u{1f600}': '\u{1f600} password=***',
  'line1\r\npassword=x\r\nline3': 'line1\r\npassword=***\r\nline3',
  '%': '%',
  '%%': '%%',
  '%4': '%4',
  '%zz': '%zz',
  '%E0%A4%A': '%E0%A4%A',
  '%C3%28 token=t': '%C3%28 token=***',
  '?url=https%3A%2F%2Fbob%3Ahunter2%40nas%2Fstream':
      '?url=https://***@nas/stream',
  'x https%3A%2F%2Fbob%3Ahunter2%40nas': 'x https://***@nas',
  'bob%3Ahunter2%40nas': '***@nas',
  '%41uthorization%3A Bearer abc123': '%41uthorization%3A Bearer ***',
  '%41uthorization%3A%20Basic%20abc123': 'Authorization: Basic ***',
  'Authorization%3A Bearer abc': 'Authorization%3A Bearer ***',
  'authorization%3Dtoken%20abc': 'authorization=token ***',
  'Bearer%20abc123': 'Bearer ***',
  'sent Bearer%20abc123 now': 'sent Bearer *** now',
  'Cookie%3A sid=1; theme=dark': 'Cookie: ***',
  'cookie%3Dsid%3D1': 'cookie=***',
  'Set-Cookie%3A a%3Db': 'Set-Cookie: ***',
  '%65yJhbGciOi.eyJzdWIi.c2lnbmF0dXJl': '***',
  'eyJhbGciOi%2EeyJzdWIi%2Ec2lnbmF0dXJl': '***',
  '%70assword%3Dhunter2': 'password=***',
  'password%3Dhunter2%26user%3Dann': 'password=***&user=ann',
  '%3Ftoken%3Dabc': '?token=***',
  'a%2540b token%3Dx': 'a%40b token=***',
  'ann%3Ahunter2%40dav.example': '***@dav.example',
  'dav%3A%2F%2Fann%3Ahunter2%40cloud.example%2Fa': 'dav://***@cloud.example/a',
  'dav%253A%252F%252Fann%253Ahunter2%2540cloud.example':
      'dav%253A%252F%252Fann%253Ahunter2%2540cloud.example',
  'ordinary %20 text %2F path': 'ordinary %20 text %2F path',
  '100%25 sure': '100%25 sure',
};

/// Name -> (input, output length, output hash).
Map<String, (String, int, int)> _hostile() => {
  'key16k': ('&${'key' * 5400}', 16201, 4117056353),
  'dot16k': ('a.' * 8000, 16000, 3530062917),
  'x16k': ('x-${'x-' * 8000}', 16002, 2608801438),
  'eyJ16k': ('eyJ' * 5400, 16200, 3071508789),
  'colon16k': ('a:' * 8000, 16000, 733402181),
  'https16k': ('https://${'a' * 16000}', 16008, 915647742),
  'slash16k': ('://' * 5400, 16200, 87496565),
  'pct16k': ('%41' * 5400, 16200, 3113051013),
  'at16k': ('a:b@' * 4000, 16000, 1653930949),
  // Stricter than before: user info past the old 128-character bound.
  'userinfo200': ('https://${'u' * 200}:pw@host/x', 18, 1172497365),
  // Stricter than before: a secret cut by the cap is masked.
  'cap-cut-plain': ('${'a' * 16380}://u:secretpw', 16406, 3233768083),
  'overlong': ('a' * 16500, 16406, 3456615000),
  'trace': ('#0  frame (package:x/x.dart:1:1)\n' * 480, 15840, 1103347045),
};
